import '../../../core/api/api_client.dart';
import '../domain/suggestion.dart';

/// Talks to the backend's suggestions endpoints. Every call is scoped to the
/// anonymous account via the shared [ApiClient] `X-User-Id` header, so votes
/// and "mine" are per-account while the ideas themselves stay anonymous.
///
/// Endpoint contract (backend to implement — see docs at the bottom of the
/// suggestions page file):
///   GET  /suggestions            → { suggestions: [ {id,text,score,my_vote,status,mine,created_at}, ... ] }
///   POST /suggestions            body {text}                → the created suggestion
///   POST /suggestions/{id}/vote  body {value: -1|0|1}       → { score, my_vote }
class SuggestionsApi {
  SuggestionsApi._();
  static final SuggestionsApi instance = SuggestionsApi._();

  final _api = ApiClient.instance;

  /// The full list, already sorted by the server (most popular first). Throws
  /// on network error so the page can show a retry state.
  Future<List<Suggestion>> list() async {
    final res = await _api.get('/suggestions');
    final raw = (res is Map ? res['suggestions'] : res) as List<dynamic>? ?? [];
    return raw
        .map((e) => Suggestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Post a new anonymous suggestion; returns the created row.
  Future<Suggestion> post(String text) async {
    final res =
        await _api.post('/suggestions', {'text': text.trim()}) as Map<String, dynamic>;
    return Suggestion.fromJson(res);
  }

  /// Set this account's vote on a suggestion: -1, 0 (clear), or +1.
  /// Returns the new (score, myVote).
  Future<(int score, int myVote)> vote(String id, int value) async {
    final res = await _api
        .post('/suggestions/$id/vote', {'value': value}) as Map<String, dynamic>;
    return ((res['score'] ?? 0) as int, (res['my_vote'] ?? 0) as int);
  }

  /// Delete one of YOUR OWN suggestions (the backend enforces author-only).
  Future<void> delete(String id) => _api.delete('/suggestions/$id');
}
