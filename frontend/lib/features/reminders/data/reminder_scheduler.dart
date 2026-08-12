import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/data/profile_store.dart';
import '../../tasks/domain/task.dart';
import '../domain/daily_digest.dart';

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
  Future<void> init() async {
    if (!_supported || _ready) return;

    tzdata.initializeTimeZones();
    await _setLocalTimezone();

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
    if (!_ready) await init();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final s = await ios?.checkPermissions();
    return s?.isEnabled ?? false;
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
      await init();
      if (!_ready) return TestNotifResult.unsupported;
    }

    final granted = await _ensureGranted();
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
  Future<bool> _ensureGranted() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await android?.areNotificationsEnabled() ?? false;
      if (enabled) return true;
      return await android?.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
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

  /// Rebuild the whole horizon: cancel everything, then schedule one digest
  /// per upcoming day that has something due.
  Future<void> _sync() async {
    if (!_ready) return;
    final profile = ProfileStore.instance;

    await _plugin.cancelAll();
    if (!profile.notifReminders) return;

    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i <= horizonDays; i++) {
      final day = DateTime(now.year, now.month, now.day + i);
      final digest = buildDailyDigest(_tasks, day);
      if (digest == null) continue;

      final fireAt = _fireTimeFor(day, profile);
      if (!fireAt.isAfter(now)) continue; // today's slot already passed

      await _plugin.zonedSchedule(
        id: _dayId(day),
        title: digest.title,
        body: digest.expandedBody,
        scheduledDate: fireAt,
        notificationDetails: _details(digest),
        androidScheduleMode: _canExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: digest.toPayload(),
      );
    }
  }

  /// The moment [day]'s digest fires: the user's chosen time, nudged out of
  /// quiet hours when they overlap (a same-day nudge only — quiet windows
  /// that wrap past midnight can't push a digest into the next day, because
  /// that day has its own).
  tz.TZDateTime _fireTimeFor(DateTime day, ProfileStore profile) {
    var minutes = profile.digestTimeMin;
    if (profile.quietEnabled) {
      final start = profile.quietStartMin, end = profile.quietEndMin;
      final wraps = end <= start;
      final inQuiet =
          wraps ? (minutes >= start || minutes < end) : (minutes >= start && minutes < end);
      if (inQuiet && end > minutes) minutes = end;
    }
    return tz.TZDateTime(
        tz.local, day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
  }

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

  static int _dayId(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  /// In-app (foreground) taps land here; route them through the same handler
  /// the background isolate uses.
  static void _onResponse(NotificationResponse response) {
    handleAction(response);
  }

  /// Executes a tray action. Runs in whichever isolate received it, with no
  /// assumptions about app state — everything needed rides in the payload.
  static Future<void> handleAction(NotificationResponse response) async {
    final digest = DailyDigest.fromPayload(response.payload);
    if (digest == null) return;

    switch (response.actionId) {
      case actionMarkAllDone:
        // The owner id persisted by the main app scopes the PATCHes to the
        // signed-in account. Per-task so one failure can't block the rest.
        await ApiClient.instance.init();
        for (final id in digest.oneOffIds) {
          try {
            await ApiClient.instance.patch('/tasks/$id', {'done': true});
          } catch (e) {
            debugPrint('mark-done from notification failed for $id: $e');
          }
        }
      case actionSnooze:
        await _showSnoozed(digest);
      default:
        // Plain tap — the OS is already opening the app to today's list.
        break;
    }
  }

  /// Re-schedules [digest] one hour from now. Runs in the background isolate,
  /// where the plugin and timezones must be set up from scratch. tz.local may
  /// fall back to UTC here — harmless, because "now + 1h" is the same instant
  /// in any zone.
  static Future<void> _showSnoozed(DailyDigest digest) async {
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
    await _plugin.zonedSchedule(
      id: _snoozeIdBase + _dayId(digest.date),
      title: digest.title,
      body: digest.expandedBody,
      scheduledDate:
          tz.TZDateTime.now(tz.local).add(const Duration(hours: 1)),
      notificationDetails: instance._details(digest),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: digest.toPayload(),
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
