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
class OnboardingGate extends StatelessWidget {
  const OnboardingGate({super.key, this.store});

  final OnboardingStore? store;

  @override
  Widget build(BuildContext context) {
    final onboarding = store ?? OnboardingStore.instance;
    return AnimatedBuilder(
      animation: onboarding,
      builder: (context, _) {
        if (!onboarding.isComplete) {
          // Show the intro inline; finishing it marks complete, which rebuilds
          // this gate into the AuthGate (phone → home).
          //
          // NOTE: onboarding runs BEFORE phone login, and login changes the API
          // owner-id (AuthStore.setOwnerId). So we deliberately do NOT pass
          // [OnboardingFlow.onFinish] here — creating tasks now would scope them
          // to the pre-login owner and they'd vanish once the user logs in.
          // The schedule step still collects the drafts fully (preview); to make
          // them real, stash the drafts on finish and replay them into TaskStore
          // on the first post-login app open (correct owner). Hook it up by
          // passing onFinish once that stash-then-create flow exists.
          return OnboardingFlow(onDone: onboarding.markComplete);
        }
        return const AuthGate();
      },
    );
  }
}
