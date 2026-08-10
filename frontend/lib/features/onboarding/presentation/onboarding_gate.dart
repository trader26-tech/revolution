import 'package:flutter/material.dart';

import '../../auth/presentation/auth_gate.dart';
import '../data/onboarding_store.dart';
import 'onboarding_flow.dart';

/// The top-level flow gate:
///
///   first launch → onboarding intro → (marks complete) → AuthGate
///   thereafter   → AuthGate directly (phone login if logged out → home)
///
/// So the sequence is exactly: **Onboarding → Phone number → Home**, and the
/// intro is only ever shown once.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key, this.store});

  final OnboardingStore? store;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  OnboardingStore get _onboarding => widget.store ?? OnboardingStore.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _onboarding,
      builder: (context, _) {
        if (!_onboarding.isComplete) {
          // Show onboarding inline; its button marks complete and this gate
          // rebuilds into the AuthGate (phone verify + login → app).
          return OnboardingFlow(onDone: _onboarding.markComplete);
        }
        return const AuthGate();
      },
    );
  }
}
