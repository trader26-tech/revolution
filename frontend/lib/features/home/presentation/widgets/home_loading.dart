import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A premium loading state for the home screen while tasks fetch from the server
/// after login. Shimmering skeleton rows that mimic the real layout, so the
/// content appears to "resolve" into place — never a flash of "All clear".
class HomeLoading extends StatefulWidget {
  const HomeLoading({super.key});

  @override
  State<HomeLoading> createState() => _HomeLoadingState();
}

class _HomeLoadingState extends State<HomeLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // A section header placeholder.
        _Shimmer(_c, child: const _Bar(width: 90, height: 18)),
        const SizedBox(height: 14),
        for (var i = 0; i < 5; i++) ...[
          _Shimmer(_c, child: const _SkeletonTile()),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 24),
        _Shimmer(_c, child: const _Bar(width: 120, height: 18)),
        const SizedBox(height: 14),
        for (var i = 0; i < 2; i++) ...[
          _Shimmer(_c, child: const _SkeletonTile()),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// A single task-card skeleton: logo circle + two text bars.
class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _Bar(width: 140, height: 13),
              SizedBox(height: 8),
              _Bar(width: 80, height: 11),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

/// Sweeps a soft highlight across [child] to give the skeleton life.
class _Shimmer extends StatelessWidget {
  const _Shimmer(this.controller, {required this.child});
  final Animation<double> controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final dx = (controller.value * 2 - 0.5) * rect.width;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.55),
                Colors.white.withValues(alpha: 0),
              ],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideGradient(dx),
            ).createShader(rect);
          },
          child: child,
        );
      },
    );
  }
}

/// Translates the shimmer gradient horizontally by [dx].
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);
  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}
