/// The lifecycle of a suggestion, driven by the creator on the server side.
enum SuggestionStatus { open, planned, done }

SuggestionStatus suggestionStatusFrom(String? s) => switch (s) {
      'planned' => SuggestionStatus.planned,
      'done' => SuggestionStatus.done,
      _ => SuggestionStatus.open,
    };

/// A community suggestion — an anonymous idea for improving the app, with a
/// score (upvotes − downvotes) and the current viewer's own vote.
class Suggestion {
  Suggestion({
    required this.id,
    required this.text,
    required this.score,
    required this.myVote,
    required this.status,
    required this.mine,
    required this.createdAt,
  });

  final String id;

  /// The idea itself — anonymous, no author shown.
  final String text;

  /// upvotes − downvotes.
  int score;

  /// The current account's vote on this: -1, 0, or +1.
  int myVote;

  SuggestionStatus status;

  /// Whether the current (anonymous) account posted this suggestion.
  final bool mine;

  final DateTime createdAt;

  bool get isDone => status == SuggestionStatus.done;
  bool get isPlanned => status == SuggestionStatus.planned;

  factory Suggestion.fromJson(Map<String, dynamic> j) => Suggestion(
        id: j['id'].toString(),
        text: (j['text'] ?? '') as String,
        score: (j['score'] ?? 0) as int,
        myVote: (j['my_vote'] ?? 0) as int,
        status: suggestionStatusFrom(j['status'] as String?),
        mine: (j['mine'] ?? false) as bool,
        createdAt: DateTime.tryParse((j['created_at'] ?? '') as String)
                ?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
