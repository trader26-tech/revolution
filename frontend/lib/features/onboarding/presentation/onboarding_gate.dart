import 'package:flutter/material.dart';

import '../data/onboarding_store.dart';
import 'onboarding_flow.dart';

/// Decides what a signed-in user opens to: the reminder-onboarding flow on
/// first run for this account, otherwise [home].
///
/// Auth happens above this (see AuthGate); by the time we're here we already
/// have a user id, threaded into onboarding so reminders it creates belong to
/// the right account.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    super.key,
    required this.home,
    this.ownerId,
    this.store = const OnboardingStore(),
  });

  final Widget home;
  final String? ownerId;
  final OnboardingStore store;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _complete;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final done = await widget.store.isComplete();
    if (mounted) setState(() => _complete = done);
  }

  Future<void> _finish() async {
    await widget.store.markComplete();
    if (mounted) setState(() => _complete = true);
  }

  @override
  Widget build(BuildContext context) {
    final complete = _complete;
    if (complete == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!complete) {
      return OnboardingFlow(onDone: _finish, ownerId: widget.ownerId);
    }
    return widget.home;
  }
}
