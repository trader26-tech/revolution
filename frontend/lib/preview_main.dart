// Throwaway preview of the new streak pill in the top bar. Not shipped.
import 'dart:ui';
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/bamboo_palette.dart';
import 'features/mascot/presentation/bobo_mascot.dart';

void main() => runApp(const _Preview());

class _Preview extends StatelessWidget {
  const _Preview();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Bamboo.mist, Bamboo.cream, Bamboo.creamHi],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Row(
                children: [
                  // avatar
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Bamboo.green.withValues(alpha: 0.14),
                      border: Border.all(
                          color: Bamboo.green.withValues(alpha: 0.55), width: 2),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Bamboo.greenDeep, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Center(child: const _PillDemo())),
                  const SizedBox(width: 12),
                  ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Bamboo.card.withValues(alpha: 0.55),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                              width: 1.2),
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: Bamboo.greenDeep, size: 26),
                      ),
                    ),
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

class _PillDemo extends StatelessWidget {
  const _PillDemo();
  @override
  Widget build(BuildContext context) {
    const accent = Bamboo.greenDeep;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.centerLeft,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 52, 8),
          decoration: BoxDecoration(
            color: Bamboo.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Bamboo.green.withValues(alpha: 0.22),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text('🔥', style: TextStyle(fontSize: 18)),
              SizedBox(width: 7),
              Text('7 day streak',
                  style: TextStyle(
                      color: accent, fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
        ),
        const Positioned(
          right: -22,
          top: -14,
          bottom: -14,
          child: BoboMascot(size: 62, mood: BoboMood.happy),
        ),
      ],
    );
  }
}
