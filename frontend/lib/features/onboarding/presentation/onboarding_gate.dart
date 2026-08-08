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

  /// The finish screen captured from the flow's `onReady`, so it becomes the
  /// SINGLE AuthGate's child once onboarding completes — the real Home preview
  /// (populated store) + name/phone claim. Null on a normal relaunch (already
  /// onboarded), where the gate just shows the plain login/app.
  Widget? _finishChild;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _onboarding,
      builder: (context, _) {
        if (!_onboarding.isComplete) {
          // Show the intro inline; finishing it hands us the finish screen via
          // onReady AND marks complete, so this gate rebuilds into ONE AuthGate
          // whose child is that finish screen — no second gate, no route push.
          return OnboardingFlow(
            onDone: _onboarding.markComplete,
            onReady: (child) => setState(() => _finishChild = child),
          );
        }
        // A single AuthGate. Its logged-out child is the onboarding finish
        // screen (real preview + claim) when we just finished; on a later
        // relaunch there's no finishChild, so it shows the plain login/app.
        return AuthGate(child: _finishChild);
      },
    );
  }
}
