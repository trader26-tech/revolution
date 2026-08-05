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
  String get asset => switch (this) {
        BoboMood.happy => 'assets/images/bobo_happy.png',
        BoboMood.excited => 'assets/images/bobo_excited.png',
        BoboMood.sleepy => 'assets/images/bobo_sleepy.png',
        BoboMood.scared => 'assets/images/bobo_scared.png',
        BoboMood.sad => 'assets/images/bobo_sad.png',
        BoboMood.writing => 'assets/images/bobo_writing.png',
        BoboMood.celebrating => 'assets/images/bobo_celebrating.png',
        BoboMood.waving => 'assets/images/bobo_waving.png',
      };
}

/// A static Bobo image for the given [mood]. Tappable via [onTap].
///
/// If the PNG for a mood is missing, Bobo renders nothing (an empty box of the
/// same size) so surrounding layout doesn't shift.
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

  @override
  Widget build(BuildContext context) {
    final height = size * 1.06;
    final image = Image.asset(
      mood.asset,
      width: size,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      // Missing PNG → empty space, never a broken-image box.
      errorBuilder: (_, _, _) => SizedBox(width: size, height: height),
    );

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
