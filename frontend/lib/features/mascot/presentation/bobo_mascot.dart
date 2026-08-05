import 'package:flutter/material.dart';

/// Bobo — the app's mascot, shown as a static illustration.
///
/// Image-only: Bobo is the PNG at `assets/images/bobo_<mood>.png`. There is no
/// code-drawn or animated version — if a mood's PNG isn't bundled yet, nothing
/// is drawn in its place (empty space), so the layout stays intact.
///
/// Bobo's moods, each mapped to a real app situation so a glance tells the user
/// how things stand:
///  * [BoboMood.happy]      — content, nothing pressing.
///  * [BoboMood.excited]    — a reminder is coming up soon.
///  * [BoboMood.sleepy]     — all calm, nothing upcoming (relaxed).
///  * [BoboMood.scared]     — a deadline is very close.
///  * [BoboMood.sad]        — something was forgotten / is overdue.
///  * [BoboMood.writing]    — the user is entering details (noting it down).
///  * [BoboMood.celebrating]— a task was completed successfully.
///  * [BoboMood.waving]     — greeting the user (onboarding welcome).
enum BoboMood { happy, excited, sleepy, scared, sad, writing, celebrating, waving }

extension _BoboMoodAsset on BoboMood {
  /// The PNG asset path for this mood.
  String get asset => 'assets/images/$_base.png';

  String get _base => switch (this) {
        BoboMood.happy => 'bobo_happy',
        BoboMood.excited => 'bobo_excited',
        BoboMood.sleepy => 'bobo_sleepy',
        BoboMood.scared => 'bobo_scared',
        BoboMood.sad => 'bobo_sad',
        BoboMood.writing => 'bobo_writing',
        BoboMood.celebrating => 'bobo_celebrating',
        BoboMood.waving => 'bobo_waving',
      };

  /// If this mood's own PNG isn't bundled yet, fall back to the closest mood
  /// whose art DOES exist — so Bobo is never invisible. Ordered from best match
  /// to a guaranteed-present default (`happy`). The first candidate that loads
  /// wins; `happy` is shipped, so there's always a final answer.
  List<String> get assetCandidates {
    final chain = switch (this) {
      BoboMood.excited => [BoboMood.excited, BoboMood.celebrating, BoboMood.happy],
      BoboMood.sad => [BoboMood.sad, BoboMood.scared, BoboMood.sleepy, BoboMood.happy],
      BoboMood.waving => [BoboMood.waving, BoboMood.happy],
      BoboMood.writing => [BoboMood.writing, BoboMood.happy],
      final m => [m, BoboMood.happy],
    };
    // De-dupe while preserving order.
    final seen = <String>{};
    return [
      for (final m in chain)
        if (seen.add(m._base)) m.asset,
    ];
  }
}

/// A static Bobo image for the given [mood]. Tappable via [onTap].
///
/// Never invisible: if the mood's own PNG isn't bundled, Bobo falls back through
/// [BoboMood.assetCandidates] to the closest mood that IS present (ultimately
/// `bobo_happy`, which always ships). Chains `errorBuilder`s so the first asset
/// that decodes is shown.
class BoboMascot extends StatelessWidget {
  const BoboMascot({
    super.key,
    this.size = 220,
    this.mood = BoboMood.happy,
    this.onTap,
  });

  final double size;
  final BoboMood mood;
  final VoidCallback? onTap;

  Widget _imageChain(List<String> candidates, double width, double height) {
    // Build from the last candidate backwards, so each earlier one falls back
    // to the next on error. The final fallback is a tiny paw glyph — reached
    // only in the impossible case that even bobo_happy is missing.
    Widget current = Center(
      child: Text('🐾', style: TextStyle(fontSize: height * 0.4)),
    );
    for (final path in candidates.reversed) {
      final next = current;
      current = Image.asset(
        path,
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => next,
      );
    }
    return current;
  }

  @override
  Widget build(BuildContext context) {
    final height = size * 1.06;
    final image = _imageChain(mood.assetCandidates, size, height);

    if (onTap == null) {
      return SizedBox(width: size, height: height, child: image);
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(width: size, height: height, child: image),
    );
  }
}
