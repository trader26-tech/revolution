import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Revo's entrance: fades in while scaling up past full size and settling back
/// with a springy overshoot, rising a touch as he arrives — a bubbly bounce,
/// not a snap. [t] runs 0->1 across his slice of the timeline.
class RevoEntrance extends StatelessWidget {
  const RevoEntrance({super.key, required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // elasticOut gives the bubbly overshoot-and-settle; easeOut fades/lifts.
    final spring = Curves.elasticOut.transform(t);
    final ease = Curves.easeOut.transform(t);
    final scale = 0.2 + spring * 0.8; // starts small, overshoots, then settles
    return Opacity(
      opacity: ease,
      child: Transform.translate(
        offset: Offset(0, (1 - ease) * 10),
        child: Transform.scale(scale: scale, child: child),
      ),
    );
  }
}

/// The question, revealed the way an AI would conjure it: each word
/// MATERIALISES on its own — blurring in from a haze, floating up into place,
/// and settling with a springy overshoot and a brief violet glow. Not typed.
///
/// [progress] is a 0->1 fraction across the question's timeline slice; from it
/// each word gets its own local 0->1 so they arrive one after another. The full
/// text is laid out invisibly beneath so the box holds its final size from
/// frame one and nothing below ever reflows.
class MagicText extends StatelessWidget {
  const MagicText({
    super.key,
    required this.text,
    required this.progress,
    required this.style,
    this.reading = false,
  });

  final String text;

  final double progress;
  final TextStyle style;

  /// "Reading" mode: words reveal strictly one-after-another in reading order
  /// (left-to-right, top-to-bottom) with a tight window and a calm slide-in — so
  /// the line reads as if it's being WRITTEN OUT as your eye moves across it,
  /// not conjured in a scatter. Off (default) keeps the original dreamy,
  /// overlapping shimmer used in onboarding.
  final bool reading;

  @override
  Widget build(BuildContext context) {
    // Split on spaces but keep newlines attached, so multi-line questions wrap
    // where they're meant to.
    final lines = text.split(String.fromCharCode(10));
    final wordCount = lines.fold<int>(0, (n, l) => n + l.split(' ').length);

    // Each word gets a START time and a WINDOW. The window is how long one word
    // takes to arrive; the starts are staggered so the FIRST begins at 0 and the
    // LAST finishes exactly at progress == 1.
    //   • reading mode → a SHORT window (little overlap): word i is essentially
    //     done before i+1 gets going, giving a clean left-to-right sweep.
    //   • default      → a WIDE window (heavy overlap): the dreamy cascade.
    final double wordWindow = reading
        ? (wordCount > 1 ? (1.0 / wordCount) * 1.6 : 1.0)
        : 0.55;
    final lastStart = wordCount > 1 ? (1 - wordWindow) : 0.0;
    final step = wordCount > 1 ? lastStart / (wordCount - 1) : 0.0;
    double localFor(int i) {
      final start = i * step;
      return ((progress - start) / wordWindow).clamp(0.0, 1.0);
    }

    var wordIndex = 0;
    final rows = <Widget>[];
    for (final line in lines) {
      final children = <Widget>[
        for (final w in line.split(' '))
          _MagicWord(
              word: w, t: localFor(wordIndex++), style: style, reading: reading),
      ];
      rows.add(
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      );
    }

    // The invisible full text underneath reserves the final height/width so the
    // materialising words never shift the layout as they land.
    return Stack(
      children: [
        Opacity(opacity: 0, child: Text(text, style: style)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        ),
      ],
    );
  }
}

/// One word of the magic reveal. Across its own 0-to-1 life [t] it fades in,
/// un-blurs from a haze, floats up, scales from small with a springy overshoot,
/// and flashes a soft violet glow that fades as it settles.
class _MagicWord extends StatelessWidget {
  const _MagicWord({
    required this.word,
    required this.t,
    required this.style,
    this.reading = false,
  });

  final String word;
  final double t;
  final TextStyle style;
  final bool reading;

  @override
  Widget build(BuildContext context) {
    if (reading) {
      // Reading mode: a calm, crisp arrival — the word fades in while sliding a
      // few px from the LEFT into place. No overshoot, no vertical float, no
      // haze, no glow — so the eye reads a clean left-to-right fill, one word
      // settling before the next starts.
      final ease = Curves.easeOutCubic.transform(t);
      return Opacity(
        opacity: ease,
        child: Transform.translate(
          offset: Offset(-10 * (1 - ease), 0),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(word, style: style),
          ),
        ),
      );
    }

    final ease = Curves.easeOut.transform(t);
    final spring = Curves.elasticOut.transform(t);

    final blur = (1 - ease) * 8; // haze that resolves as it arrives
    final lift = (1 - ease) * 14; // floats up into place
    final scale = 0.7 + spring * 0.3; // small, overshoot, then settle
    // Glow blooms mid-arrival then fades to nothing. Hard-zero once basically
    // settled so no faint halo can linger on a word (esp. the last one).
    final glow = t >= 0.999 ? 0.0 : math.sin(t.clamp(0.0, 1.0) * math.pi);

    Widget label = Text(
      word,
      style: style.copyWith(
        shadows: [
          Shadow(
            color: AppColors.accent.withValues(alpha: 0.55 * glow),
            blurRadius: 18 * glow,
          ),
        ],
      ),
    );

    // A cheap per-word blur while it's arriving, dropped once settled so
    // finished text stays crisp.
    if (blur > 0.05) {
      label = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: label,
      );
    }

    return Opacity(
      opacity: ease,
      child: Transform.translate(
        offset: Offset(0, lift),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: label,
          ),
        ),
      ),
    );
  }
}
