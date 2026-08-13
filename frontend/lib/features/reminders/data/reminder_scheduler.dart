import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../calendar/domain/occurrences.dart';
import '../../details/domain/currency.dart';
import '../../settings/data/profile_store.dart';
import '../../tasks/domain/task.dart';
import '../domain/daily_digest.dart';
import '../domain/reminder_notice.dart';

/// The outcome of [ReminderScheduler.sendTestNotification], so the settings UI
/// can tell the user exactly what happened.
enum TestNotifResult {
  /// Posted successfully — check your tray.
  sent,

  /// Notifications are turned off for the app — send them to system settings.
  denied,

  /// This platform can't post local notifications (e.g. web).
  unsupported,

  /// An unexpected error while posting.
  failed,
}

/// The user taps "Mark all done" or "Snooze 1 hr" on the notification — often
/// with the app killed — and the OS spins up a fresh background isolate to run
/// this. It must be a top-level entry point (not a method) to survive
/// tree-shaking in release builds.
@pragma('vm:entry-point')
Future<void> reminderActionBackground(NotificationResponse response) =>
    ReminderScheduler.handleAction(response);

/// Schedules the app's ONE daily notification: a digest of everything due
/// that day, fired locally at the user's chosen time.
///
/// Design decisions, in order of importance:
/// - One notification per day, ever. Each day within the horizon gets a single
///   digest (id = yyyymmdd); days with nothing due get silence.
/// - Notifications are scheduled ON the device from the tasks the app already
///   knows, so they fire offline and need no push infrastructure. The cost:
///   the schedule must be rebuilt whenever tasks change ([onTasksChanged]) —
///   the horizon is re-derived, not incrementally patched, so it can't drift.
/// - Interactive in the tray: "Mark all done" completes the day's one-off
///   tasks straight from the notification (a background isolate PATCHes the
///   server); "Snooze 1 hr" re-surfaces the same digest later. Recurring tasks
///   are listed but never bulk-completed — `done` on a Task ends its whole
///   series, which is not what a tray tap means.
class ReminderScheduler {
  ReminderScheduler._();
  static final ReminderScheduler instance = ReminderScheduler._();

  static const _channelId = 'daily_digest_v1';
  static const _channelName = 'Daily summary';
  static const _channelDescription =
      'One notification each day summarizing what’s due';

  /// iOS category carrying the tray actions; must match AppDelegate wiring.
  static const categoryId = 'DAILY_DIGEST';
  static const actionMarkAllDone = 'MARK_ALL_DONE';
  static const actionSnooze = 'SNOOZE_1H';

  /// How many days of digests are kept scheduled ahead. 30 days with one
  /// notification each stays well under iOS's 64-pending-notification cap.
  static const horizonDays = 30;

  /// Snoozed copies get their own id so they can't collide with a day id.
  static const _snoozeIdBase = 900000000;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  List<Task> _tasks = const [];
  Timer? _debounce;
  bool _canExact = false;

  // defaultTargetPlatform (not dart:io Platform) so this file also compiles
  // for the web preview build, where the scheduler simply no-ops.
  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Initialize the plugin + timezone database. Call once at startup, before
  /// any store starts notifying. No-op on web/desktop.
  ///
  /// Hardened so nothing here can hang the caller: the timezone lookup is
  /// time-boxed (a slow/failed native call falls back to UTC instead of
  /// blocking), and on Android we explicitly create the notification CHANNEL —
  /// several OEMs (Samsung/Xiaomi/…) silently drop notifications posted to a
  /// channel that was never created.
  Future<void> init() async {
    if (!_supported || _ready) return;

    try {
      tzdata.initializeTimeZones();
      // Never let a stuck platform timezone call hang startup / the test button.
      await _setLocalTimezone().timeout(const Duration(seconds: 3),
          onTimeout: () {});
    } catch (_) {
      // UTC default stands — a wrong offset is far better than a hang.
    }

    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('ic_stat_notification'),
        iOS: DarwinInitializationSettings(
          // Permission is requested explicitly (ensurePermissions) once the
          // user reaches the app, not silently at first launch.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              categoryId,
              actions: [
                DarwinNotificationAction.plain(
                    actionMarkAllDone, 'Mark all done'),
                DarwinNotificationAction.plain(actionSnooze, 'Snooze 1 hr'),
              ],
              options: const {
                // Keep the item list visible on the lock screen even with
                // previews hidden — the digest IS the content.
                DarwinNotificationCategoryOption.hiddenPreviewShowSubtitle,
              },
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: _onResponse,
      onDidReceiveBackgroundNotificationResponse: reminderActionBackground,
    );

    // Create the Android channel up front so the very first notification (incl.
    // the test) is guaranteed a home. Idempotent — safe to call every launch.
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
      } catch (_) {
        // Non-fatal — show() would still lazily create it.
      }
    }

    _ready = true;

    // Reschedule when notification prefs change (time, quiet hours, toggle).
    ProfileStore.instance.addListener(_requestSync);
  }

  /// Ask the OS for notification permission (Android 13+ runtime permission,
  /// iOS alert/badge/sound). Call once the user is inside the app.
  Future<void> ensurePermissions() async {
    if (!_supported || !_ready) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      // Exact alarms: granted automatically to reminder apps via
      // USE_EXACT_ALARM (see AndroidManifest). If an OEM still says no, fall
      // back to inexact — a daily digest survives a few minutes of drift.
      _canExact = await android?.canScheduleExactNotifications() ?? false;
    } else {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
    _requestSync();
  }

  /// Whether the OS currently allows this app to post notifications. Lets the
  /// settings button show the right state ("Allow" vs "Send a test").
  Future<bool> notificationsAllowed() async {
    if (!_supported) return false;
    if (!_ready) {
      try {
        await init().timeout(const Duration(seconds: 8));
      } catch (_) {}
      if (!_ready) return false;
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await android
                ?.areNotificationsEnabled()
                .timeout(const Duration(seconds: 3), onTimeout: () => false) ??
            false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final s = await ios
          ?.checkPermissions()
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      return s?.isEnabled ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request notification permission (prompts the OS dialog). Returns whether
  /// it's granted afterwards — so the "Allow notifications" button can flip to
  /// "Send a test" on success.
  Future<bool> requestPermission() => _ensureGranted();

  /// Fire an immediate notification showing TODAY's real digest, so the user
  /// sees exactly what their daily reminder will look like — not a generic
  /// "this is a test". Ensures permission first; fires on the same channel the
  /// scheduled digest uses, so a success here proves the real ones will land.
  Future<TestNotifResult> sendTestNotification() async {
    if (!_supported) return TestNotifResult.unsupported;
    if (!_ready) {
      // Time-box init so a stuck native call can't leave the button spinning.
      try {
        await init().timeout(const Duration(seconds: 8));
      } catch (_) {
        // ignore — we check _ready below
      }
      if (!_ready) return TestNotifResult.failed;
    }

    bool granted;
    try {
      granted = await _ensureGranted();
    } catch (_) {
      return TestNotifResult.failed;
    }
    if (!granted) return TestNotifResult.denied;

    // Build TODAY's digest from the real tasks. If nothing's due today, show a
    // friendly "all clear" so the notification still demonstrates delivery.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final digest = buildDailyDigest(_tasks, today);

    try {
      if (digest != null) {
        // Real content — same rich style as the scheduled digest.
        await _plugin.show(
          id: _testId,
          title: digest.title,
          body: digest.expandedBody,
          notificationDetails: _details(digest),
          payload: digest.toPayload(),
        );
      } else {
        // Nothing due today — a clean "you're all caught up" digest.
        await _plugin.show(
          id: _testId,
          title: 'Today’s reminders',
          body: 'You’re all caught up — nothing due today. 🎉',
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.high,
              priority: Priority.high,
              icon: 'ic_stat_notification',
              color: AppColors.accentDeep,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      }
      return TestNotifResult.sent;
    } catch (_) {
      return TestNotifResult.failed;
    }
  }

  /// Ask for (and report) notification permission. True if we can post.
  ///
  /// Every native call is time-boxed so the button can NEVER spin forever: if
  /// the OS is slow or an OEM stalls, we resolve to a definite true/false and
  /// let the user retry, instead of hanging. On Android 13+ we always ATTEMPT
  /// the request when not already enabled, so the system dialog actually shows.
  Future<bool> _ensureGranted() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;

      final enabled = await android
          .areNotificationsEnabled()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
      if (enabled == true) return true;

      // Show the system permission dialog (Android 13+). On <13 this resolves
      // true immediately (no runtime permission). Time-boxed so a dialog the
      // user never answers doesn't leave the button spinning — they can tap
      // again once they've decided.
      final granted = await android
          .requestNotificationsPermission()
          .timeout(const Duration(seconds: 60), onTimeout: () => null);
      if (granted != null) return granted;

      // Timed out waiting on the dialog — re-check the actual state.
      return await android
          .areNotificationsEnabled()
          .timeout(const Duration(seconds: 2), onTimeout: () => false) ??
          false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final r = await ios
        ?.requestPermissions(alert: true, badge: true, sound: true)
        .timeout(const Duration(seconds: 60), onTimeout: () => false);
    return r ?? false;
  }

  /// A fixed id for the test notification (well clear of day/snooze ids).
  static const _testId = 999999999;

  /// Called by [TaskStore] after every change; debounced so a burst of
  /// mutations rebuilds the schedule once.
  void onTasksChanged(List<Task> tasks) {
    if (!_supported) return;
    _tasks = tasks;
    _requestSync();
  }

  void _requestSync() {
    if (!_ready) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _sync().catchError((Object e) {
        debugPrint('ReminderScheduler sync failed: $e');
      });
    });
  }

  /// Rebuild the whole horizon: cancel everything, then schedule ONE
  /// notification PER REMINDER, each at its own due time. Recurring reminders
  /// are expanded into their upcoming occurrences (auto-rolling), so a monthly
  /// subscription keeps alerting without the user doing anything. A reminder
  /// with no time fires at the user's default reminder time; one with no date
  /// (an unscheduled General note) is simply skipped.
  Future<void> _sync() async {
    if (!_ready) return;
    final profile = ProfileStore.instance;

    await _plugin.cancelAll();
    if (!profile.notifReminders) return;

    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);
    final end = today.add(const Duration(days: horizonDays));

    // Every dated appearance of every active reminder in the window — one-offs
    // once, recurring ones stepped forward. Sorted soonest-first.
    final eligible =
        _tasks.where((t) => t.reminderOn && !t.done).toList(growable: false);
    final occurrences = expandOccurrences(eligible, from: today, to: end);

    // Respect the platform pending-notification cap (iOS ~64). Take the soonest.
    var scheduled = 0;
    for (final occ in occurrences) {
      if (scheduled >= _maxPending) break;

      final fireAt = _fireTimeForTask(occ.task, occ.date, profile);
      if (!fireAt.isAfter(now)) continue; // its moment has already passed

      final recurring = occ.task.repeat != RepeatCadence.none;
      final notice = ReminderNotice(
        taskId: occ.task.id,
        title: occ.task.title,
        body: _bodyFor(occ.task),
        fireAt: DateTime(fireAt.year, fireAt.month, fireAt.day, fireAt.hour,
            fireAt.minute),
        recurring: recurring,
      );

      await _plugin.zonedSchedule(
        id: _reminderId(occ.task.id, occ.date),
        title: notice.title,
        body: notice.body.isEmpty ? 'Reminder' : notice.body,
        scheduledDate: fireAt,
        notificationDetails: _reminderDetails(notice),
        androidScheduleMode: _canExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: notice.toPayload(),
      );
      scheduled++;
    }
  }

  /// The moment reminder [task] should fire on [date]: the task's OWN time when
  /// it has one, else the user's default reminder time — then nudged out of
  /// quiet hours if it lands inside them.
  tz.TZDateTime _fireTimeForTask(
      Task task, DateTime date, ProfileStore profile) {
    final due = task.dueAt;
    final hasTime = due != null && !(due.hour == 0 && due.minute == 0);
    var minutes =
        hasTime ? due.hour * 60 + due.minute : profile.defaultReminderMin;

    if (profile.quietEnabled) {
      final start = profile.quietStartMin, end = profile.quietEndMin;
      final wraps = end <= start;
      final inQuiet = wraps
          ? (minutes >= start || minutes < end)
          : (minutes >= start && minutes < end);
      if (inQuiet && end > minutes) minutes = end;
    }
    return tz.TZDateTime(
        tz.local, date.year, date.month, date.day, minutes ~/ 60, minutes % 60);
  }

  /// The supporting line under a reminder's name — its amount, else its note,
  /// else a plain "Due today". Kept short; the title carries the name.
  String _bodyFor(Task task) {
    if (task.hasAmount) {
      final cur = currencyOf(task.currency);
      final a = task.amount!;
      final body = a == a.roundToDouble()
          ? a.round().toString()
          : a.toStringAsFixed(2);
      return '${cur.symbol}$body';
    }
    final note = (task.note ?? '').trim();
    if (note.isNotEmpty) return note;
    return 'Reminder';
  }

  /// A stable, collision-free notification id for a (task, date) pair. Hashes
  /// the task id + the day so the same occurrence keeps the same id across
  /// re-syncs (no duplicate alarms), and different occurrences never clash.
  static int _reminderId(String taskId, DateTime date) {
    final day = date.year * 10000 + date.month * 100 + date.day;
    final h = Object.hash(taskId, day) & 0x3FFFFFFF; // keep positive, < 2^30
    return h;
  }

  /// Per-reminder tray styling + the single-task "Mark done" action.
  NotificationDetails _reminderDetails(ReminderNotice notice) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_notification',
        color: AppColors.accentDeep,
        actions: [
          // Only a one-off can be completed from the tray — completing a
          // recurring series from a single alert is never the intent.
          if (!notice.recurring)
            const AndroidNotificationAction(
              actionMarkAllDone,
              'Mark done',
              showsUserInterface: false,
            ),
          const AndroidNotificationAction(
            actionSnooze,
            'Snooze 1 hr',
            showsUserInterface: false,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: categoryId,
        threadIdentifier: 'reminders',
        interruptionLevel: InterruptionLevel.active,
      ),
    );
  }

  /// Cap on how many reminders we keep scheduled at once — stays under iOS's
  /// 64-pending limit with headroom for the test + snoozed copies.
  static const _maxPending = 56;

  NotificationDetails _details(DailyDigest digest) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_notification',
        color: AppColors.accentDeep,
        // Expanded view: one clean line per item, count in the summary row.
        styleInformation: InboxStyleInformation(
          digest.lines,
          contentTitle: digest.title,
          summaryText:
              digest.count == 1 ? '1 item' : '${digest.count} items',
        ),
        actions: [
          const AndroidNotificationAction(
            actionMarkAllDone,
            'Mark all done',
            // Runs in the background isolate; the tray notification is
            // dismissed by the tap (cancelNotification defaults to true).
            showsUserInterface: false,
          ),
          const AndroidNotificationAction(
            actionSnooze,
            'Snooze 1 hr',
            showsUserInterface: false,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        categoryIdentifier: categoryId,
        threadIdentifier: 'daily_digest',
        subtitle: _subtitleFor(digest.date),
        interruptionLevel: InterruptionLevel.active,
      ),
    );
  }

  /// "Thursday, 7 August" — grounds the digest without repeating "today".
  static String _subtitleFor(DateTime d) {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday',
    ];
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December',
    ];
    return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  /// In-app (foreground) taps land here; route them through the same handler
  /// the background isolate uses.
  static void _onResponse(NotificationResponse response) {
    handleAction(response);
  }

  /// Executes a tray action. Runs in whichever isolate received it, with no
  /// assumptions about app state — everything needed rides in the payload.
  static Future<void> handleAction(NotificationResponse response) async {
    final notice = ReminderNotice.fromPayload(response.payload);
    if (notice == null) return;

    switch (response.actionId) {
      case actionMarkAllDone:
        // Mark THIS reminder's task done. The owner id persisted by the main
        // app scopes the PATCH to the signed-in account. (Only shown for
        // one-offs, so this never ends a recurring series.)
        await ApiClient.instance.init();
        try {
          await ApiClient.instance
              .patch('/tasks/${notice.taskId}', {'done': true});
        } catch (e) {
          debugPrint('mark-done from notification failed: $e');
        }
      case actionSnooze:
        await _showSnoozed(notice);
      default:
        // Plain tap — the OS is already opening the app.
        break;
    }
  }

  /// Re-schedules a reminder one hour from now. Runs in the background isolate,
  /// where the plugin and timezones must be set up from scratch. tz.local may
  /// fall back to UTC here — harmless, because "now + 1h" is the same instant
  /// in any zone.
  static Future<void> _showSnoozed(ReminderNotice notice) async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: InitializationSettings(
        android:
            const AndroidInitializationSettings('ic_stat_notification'),
        iOS: const DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    final at = tz.TZDateTime.now(tz.local).add(const Duration(hours: 1));
    await _plugin.zonedSchedule(
      id: _snoozeIdBase + (notice.taskId.hashCode & 0x7FFFF),
      title: notice.title,
      body: notice.body.isEmpty ? 'Reminder' : notice.body,
      scheduledDate: at,
      notificationDetails: instance._reminderDetails(notice),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: ReminderNotice(
        taskId: notice.taskId,
        title: notice.title,
        body: notice.body,
        fireAt: DateTime(at.year, at.month, at.day, at.hour, at.minute),
        recurring: notice.recurring,
      ).toPayload(),
    );
  }

  /// Point the tz database at the device's zone so "8:00 AM" means the user's
  /// 8 AM. Falls back to matching the current UTC offset if the platform
  /// lookup fails.
  static Future<void> _setLocalTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      return;
    } catch (_) {
      // fall through to offset matching
    }
    try {
      final offset = DateTime.now().timeZoneOffset;
      for (final location in tz.timeZoneDatabase.locations.values) {
        if (tz.TZDateTime.now(location).timeZoneOffset == offset) {
          tz.setLocalLocation(location);
          return;
        }
      }
    } catch (_) {
      // UTC default stands; daily times will be offset but nothing crashes.
    }
  }
}
