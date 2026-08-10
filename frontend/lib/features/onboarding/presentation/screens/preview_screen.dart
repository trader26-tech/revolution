import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Screen 3 — a peek at the app itself.
///
/// A phone-frame mock of the Home screen (greeting + a couple of the real
/// Up-Next cards) so the user sees, at a glance, what they're stepping into
/// before they verify. Drawn in Flutter — always crisp, no screenshot asset.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, this.onContinue});

  /// Advance to phone verify/login. Null in previews → the button hides.
  final VoidCallback? onContinue;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  double _seg(double a, double b) =>
      ((_enter.value - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: AnimatedBuilder(
          animation: _enter,
          builder: (context, _) {
            final phoneT = Curves.easeOutBack.transform(_seg(0.0, 0.6));
            final headT = _seg(0.25, 0.7);
            final btnT = _seg(0.55, 1.0);
            return Column(
              children: [
                const Spacer(flex: 2),
                _fade(
                  headT,
                  const Column(
                    children: [
                      Text(
                        'Everything, in one calm place',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 21,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: AppColors.ink,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Your subscriptions, SIPs and dates — at a glance.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // The phone mock.
                Expanded(
                  flex: 10,
                  child: Opacity(
                    opacity: phoneT.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, 24 * (1 - phoneT)),
                      child: Transform.scale(
                        scale: 0.88 + 0.12 * phoneT,
                        child: const _PhoneMock(),
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 1),
                if (widget.onContinue != null)
                  _fade(
                    btnT,
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: widget.onContinue,
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              AppColors.accent,
                              AppColors.accentDeep
                            ]),
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Get started',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  )),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 18, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _fade(double t, Widget child) {
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
    );
  }
}

/// A stylised phone showing a miniature Home screen — a device frame with a
/// notch, a greeting, and a couple of Up-Next cards. Purely decorative.
class _PhoneMock extends StatelessWidget {
  const _PhoneMock();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 0.5,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0716),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: AppColors.cardBorder, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.18),
                blurRadius: 40,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.bgTop, AppColors.bg],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Notch.
                  Center(
                    child: Container(
                      width: 46,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  // Eyebrow + greeting.
                  Row(
                    children: [
                      const Icon(Icons.nightlight_round,
                          size: 9, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text('REVOLUTION',
                          style: TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: AppColors.accent.withValues(alpha: 0.85),
                          )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      colors: [AppColors.ink, Color(0xFFB9A8FF)],
                    ).createShader(r),
                    child: const Text('Good evening',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: Colors.white,
                        )),
                  ),
                  const SizedBox(height: 14),
                  const Text('UP NEXT',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: AppColors.inkFaint,
                      )),
                  const SizedBox(height: 8),
                  const _MiniCard(
                    icon: Icons.play_circle_fill_rounded,
                    title: 'Netflix',
                    sub: '₹649 · monthly',
                    when: 'TOMORROW',
                  ),
                  const SizedBox(height: 8),
                  const _MiniCard(
                    icon: Icons.trending_up_rounded,
                    title: 'Wint Wealth',
                    sub: '₹25,000 · SIP',
                    when: 'FRI 15',
                  ),
                  const SizedBox(height: 8),
                  const _MiniCard(
                    icon: Icons.cake_rounded,
                    title: 'Michael',
                    sub: 'Birthday',
                    when: 'SAT 16',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.when,
  });
  final IconData icon;
  final String title;
  final String sub;
  final String when;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.accent.withValues(alpha: 0.08), AppColors.card],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: AppColors.accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    )),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(when,
                style: const TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                  color: AppColors.accent,
                )),
          ),
        ],
      ),
    );
  }
}
