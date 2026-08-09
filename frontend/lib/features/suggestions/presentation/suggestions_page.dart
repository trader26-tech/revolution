import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mascot.dart';
import '../data/suggestions_api.dart';
import '../domain/suggestion.dart';

/// The Ideas board — an anonymous, community-driven suggestion wall.
///
/// Anyone can post an idea; anyone can up/down-vote; the most-loved float to the
/// top. When the creator ships an idea (status → done on the server), it shows a
/// "Shipped" state, and the next time you open the board Revo pops up to
/// celebrate the ones you backed — a warm loop between the makers and you.
class SuggestionsPage extends StatefulWidget {
  const SuggestionsPage({super.key});

  @override
  State<SuggestionsPage> createState() => _SuggestionsPageState();
}

class _SuggestionsPageState extends State<SuggestionsPage> {
  final _api = SuggestionsApi.instance;

  List<Suggestion>? _items; // null = loading
  Object? _error;
  bool _posting = false;

  /// Ids of 'done' suggestions we've already celebrated, so Revo only pops for
  /// NEWLY-shipped ones. Persisted across launches.
  static const _seenKey = 'suggestions_seen_done_v1';
  Set<String> _seenDone = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _error = null);
    try {
      final prefs = await SharedPreferences.getInstance();
      _seenDone = (prefs.getStringList(_seenKey) ?? const []).toSet();
      final list = await _api.list();
      if (!mounted) return;
      setState(() {
        _items = list;
        _error = null;
      });
      _celebrateNewlyShipped(list, prefs);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  /// Any idea the user BACKED (up-voted) or POSTED that just shipped → Revo.
  Future<void> _celebrateNewlyShipped(
      List<Suggestion> list, SharedPreferences prefs) async {
    final fresh = list.where((s) =>
        s.isDone &&
        (s.mine || s.myVote > 0) &&
        !_seenDone.contains(s.id));
    if (fresh.isEmpty) return;
    // Mark them seen so we never celebrate twice.
    final ids = {..._seenDone, for (final s in fresh) s.id};
    await prefs.setStringList(_seenKey, ids.toList());
    _seenDone = ids;
    if (!mounted) return;
    await showShippedCelebration(context, fresh.toList());
  }

  Future<void> _openComposer() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ComposerSheet(),
    );
    if (text == null || text.trim().isEmpty) return;
    setState(() => _posting = true);
    try {
      final created = await _api.post(text.trim());
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _items = [created, ...?_items];
        _posting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _posting = false);
      _snack('Couldn’t post right now — try again.');
    }
  }

  /// Toggle the vote: tapping the same arrow again clears it.
  Future<void> _vote(Suggestion s, int dir) async {
    final target = s.myVote == dir ? 0 : dir;
    final prevScore = s.score, prevVote = s.myVote;
    // Optimistic update.
    setState(() {
      s.score += (target - s.myVote);
      s.myVote = target;
    });
    HapticFeedback.selectionClick();
    try {
      final (score, myVote) = await _api.vote(s.id, target);
      if (!mounted) return;
      setState(() {
        s.score = score;
        s.myVote = myVote;
        _resort();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        s.score = prevScore;
        s.myVote = prevVote;
      });
      _snack('Vote didn’t save — check your connection.');
    }
  }

  void _resort() {
    _items?.sort((a, b) {
      // Shipped sink to their own section below; within a group, score desc.
      final ga = a.isDone ? 1 : 0, gb = b.isDone ? 1 : 0;
      if (ga != gb) return ga - gb;
      if (a.score != b.score) return b.score - a.score;
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(onPost: _openComposer, posting: _posting),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null && _items == null) {
      return _ErrorState(onRetry: _load);
    }
    if (_items == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    final items = _items!;
    if (items.isEmpty) return _EmptyState(onPost: _openComposer);

    _resort();
    final open = items.where((s) => !s.isDone).toList();
    final shipped = items.where((s) => s.isDone).toList();

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => _load(showSpinner: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          for (final s in open)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SuggestionCard(suggestion: s, onVote: (d) => _vote(s, d)),
            ),
          if (shipped.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 18, 4, 10),
              child: Row(
                children: [
                  Icon(Icons.rocket_launch_rounded,
                      size: 16, color: AppColors.accent),
                  SizedBox(width: 8),
                  Text('Shipped',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: AppColors.accent)),
                ],
              ),
            ),
            for (final s in shipped)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child:
                    _SuggestionCard(suggestion: s, onVote: (d) => _vote(s, d)),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.onPost, required this.posting});
  final VoidCallback onPost;
  final bool posting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
              width: 46, height: 46, child: AnimatedMascot(size: 46)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ideas',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.ink)),
                Text('Shape Revolution — anonymously.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: posting ? null : onPost,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentDeep]),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 5)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (posting)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                  else
                    const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  const Text('Suggest',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── One suggestion card ──────────────────────────────────────────────────────
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.suggestion, required this.onVote});
  final Suggestion suggestion;
  final ValueChanged<int> onVote; // +1 or -1

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: s.isDone
              ? AppColors.accent.withValues(alpha: 0.4)
              : AppColors.glassBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The vote stack — up ▲ score ▼.
          _VoteStack(
            score: s.score,
            myVote: s.myVote,
            onUp: () => onVote(1),
            onDown: () => onVote(-1),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.text,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatusChip(status: s.status),
                    if (s.mine) ...[
                      const SizedBox(width: 6),
                      const _Tag(text: 'Yours', muted: true),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteStack extends StatelessWidget {
  const _VoteStack({
    required this.score,
    required this.myVote,
    required this.onUp,
    required this.onDown,
  });
  final int score;
  final int myVote;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _arrow(Icons.keyboard_arrow_up_rounded, myVote > 0, onUp),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '$score',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: myVote > 0
                  ? AppColors.accent
                  : (myVote < 0 ? AppColors.inkSoft : AppColors.ink),
            ),
          ),
        ),
        _arrow(Icons.keyboard_arrow_down_rounded, myVote < 0, onDown),
      ],
    );
  }

  Widget _arrow(IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 34,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active
                  ? AppColors.accent.withValues(alpha: 0.5)
                  : AppColors.glassBorder),
        ),
        child: Icon(icon,
            size: 22, color: active ? AppColors.accent : AppColors.inkSoft),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final SuggestionStatus status;

  @override
  Widget build(BuildContext context) {
    final (String label, IconData icon) = switch (status) {
      SuggestionStatus.done => ('Shipped', Icons.check_circle_rounded),
      SuggestionStatus.planned => ('Planned', Icons.timelapse_rounded),
      SuggestionStatus.open => ('Open', Icons.lightbulb_outline_rounded),
    };
    final strong = status != SuggestionStatus.open;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: strong ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12,
              color: strong ? AppColors.accent : AppColors.inkSoft),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: strong ? AppColors.accent : AppColors.inkSoft)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.muted = false});
  final String text;
  final bool muted;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted ? AppColors.inkFaint : AppColors.inkSoft)),
    );
  }
}

// ── Composer bottom sheet ────────────────────────────────────────────────────
class _ComposerSheet extends StatefulWidget {
  const _ComposerSheet();
  @override
  State<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends State<_ComposerSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewPadding.bottom),
        decoration: const BoxDecoration(
          color: AppColors.bgTop,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.inkFaint.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Suggest an idea',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppColors.ink)),
                const SizedBox(height: 4),
                const Text('Posted anonymously. No names, ever.',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft)),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    maxLines: 4,
                    minLines: 3,
                    maxLength: 280,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: AppColors.ink,
                        fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'What would make Revolution better?',
                      hintStyle: TextStyle(color: AppColors.inkFaint),
                      counterStyle: TextStyle(color: AppColors.inkFaint),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      final t = _controller.text.trim();
                      if (t.isEmpty) return;
                      Navigator.of(context).pop(t);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppColors.accent, AppColors.accentDeep]),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Post anonymously',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty / error states ─────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPost});
  final VoidCallback onPost;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 96, height: 96, child: AnimatedMascot(size: 96)),
            const SizedBox(height: 20),
            const Text('No ideas yet',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: 6),
            const Text(
              'Be the first — tell us what to build next. Revo’s listening.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkSoft, height: 1.35),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onPost,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.accentDeep]),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('Share an idea',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.inkFaint),
            const SizedBox(height: 16),
            const Text('Couldn’t load ideas',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: 6),
            const Text('Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.inkSoft)),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => onRetry(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: const Text('Retry',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Revo "shipped!" celebration ──────────────────────────────────────────────

/// A full-screen Revo celebration for ideas the user backed that just shipped.
Future<void> showShippedCelebration(
    BuildContext context, List<Suggestion> shipped) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => _ShippedOverlay(shipped: shipped),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _ShippedOverlay extends StatefulWidget {
  const _ShippedOverlay({required this.shipped});
  final List<Suggestion> shipped;
  @override
  State<_ShippedOverlay> createState() => _ShippedOverlayState();
}

class _ShippedOverlayState extends State<_ShippedOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();
  late final AnimationController _life = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _pop.dispose();
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final one = widget.shipped.length == 1;
    final headline = one ? 'Your idea shipped!' : 'Your ideas shipped!';
    final sub = one
        ? 'The one you backed is now live. Thanks for shaping Revolution.'
        : '${widget.shipped.length} ideas you backed are now live. Thanks for shaping Revolution.';

    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: AnimatedBuilder(
              animation: Listenable.merge([_pop, _life]),
              builder: (context, _) {
                final p = _pop.value;
                final pop = Curves.easeOutBack.transform(p.clamp(0.0, 1.0));
                final t = _life.value;
                final bob = math.sin(t * 2 * math.pi) * 4;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 150,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                              size: const Size(180, 150),
                              painter: _SparkPainter(p)),
                          Transform.translate(
                            offset: Offset(0, bob),
                            child: Transform.scale(
                              scale: 0.6 + 0.4 * pop,
                              child: const AnimatedMascot(size: 104),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: ((p - 0.3) / 0.5).clamp(0.0, 1.0),
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (r) => const LinearGradient(colors: [
                              AppColors.ink,
                              Color(0xFFB9A8FF)
                            ]).createShader(r),
                            child: Text(headline,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                    color: Colors.white)),
                          ),
                          const SizedBox(height: 8),
                          Text(sub,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.inkSoft)),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 11),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                AppColors.accent,
                                AppColors.accentDeep
                              ]),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text('Amazing',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.p);
  final double p;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final e = Curves.easeOut.transform(p.clamp(0.0, 1.0));
    final fade = (1 - ((p - 0.55) / 0.45)).clamp(0.0, 1.0);
    if (fade <= 0) return;
    const n = 12;
    final maxR = size.width * 0.42;
    for (var i = 0; i < n; i++) {
      final a = (i / n) * 2 * math.pi + 0.3;
      final r = maxR * e;
      final pos = c + Offset(math.cos(a), math.sin(a)) * r;
      final tail = pos - Offset(math.cos(a), math.sin(a)) * 10;
      final paint = Paint()
        ..color = (i.isEven ? AppColors.accent : const Color(0xFFB9A8FF))
            .withValues(alpha: fade)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(tail, pos, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.p != p;
}
