import '../../../core/network/api_client.dart';
import '../domain/reminder.dart';

/// Talks to the FastAPI backend, which is the only writer to Supabase.
///
/// Ownership is carried by the `X-Owner-Id` header, set to the signed-in user's
/// id (from phone login). Every request is therefore scoped to that account.
/// The `demo-user` fallback only applies when no id is supplied (e.g. tests).
class RemindersRepository {
  RemindersRepository({ApiClient? api, String? ownerId})
      : _api = api ?? ApiClient(),
        _ownerId = (ownerId != null && ownerId.isNotEmpty)
            ? ownerId
            : _placeholderOwnerId;

  final ApiClient _api;
  final String _ownerId;

  static const String _placeholderOwnerId = 'demo-user';

  Map<String, String> get _ownerHeader => {'X-Owner-Id': _ownerId};

  Future<List<Reminder>> list() async {
    final json = await _api.get('/reminders', headers: _ownerHeader);
    return (json as List)
        .map((e) => Reminder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Reminder> create(ReminderDraft draft) async {
    final json = await _api.post(
      '/reminders',
      body: draft.toJson(),
      headers: _ownerHeader,
    );
    return Reminder.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _api.delete('/reminders/$id', headers: _ownerHeader);
  }
}
