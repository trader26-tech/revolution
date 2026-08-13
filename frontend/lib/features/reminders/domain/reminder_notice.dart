import 'dart:convert';

/// One scheduled per-reminder notification's content + the data its tray
/// actions need. Precomputed at schedule time so the background isolate (which
/// may fire days later with no app state) has everything on the payload.
///
/// Pure Dart — no plugin imports — so it's testable and safe in the isolate.
class ReminderNotice {
  const ReminderNotice({
    required this.taskId,
    required this.title,
    required this.body,
    required this.fireAt,
    required this.recurring,
  });

  /// The task this reminder is for — the "Mark done" action patches it.
  final String taskId;

  /// Notification headline — the reminder's name.
  final String title;

  /// The supporting line (amount / note / "Due today"), may be empty.
  final String body;

  /// When it's scheduled to fire (local). Carried so a history view can show it.
  final DateTime fireAt;

  /// Whether this is one occurrence of a recurring task. A recurring task is
  /// never bulk-completed from the tray (that would end the whole series).
  final bool recurring;

  String toPayload() => jsonEncode({
        'task_id': taskId,
        'title': title,
        'body': body,
        'fire_at': fireAt.toIso8601String(),
        'recurring': recurring,
      });

  static ReminderNotice? fromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final j = jsonDecode(payload) as Map<String, dynamic>;
      return ReminderNotice(
        taskId: j['task_id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        fireAt: DateTime.parse(j['fire_at'] as String),
        recurring: j['recurring'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }
}
