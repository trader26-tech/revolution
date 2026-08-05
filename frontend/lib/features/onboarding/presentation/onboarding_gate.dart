import 'package:flutter/material.dart';

import '../data/onboarding_store.dart';
import 'onboarding_flow.dart';

/// Decides what the app opens to: onboarding on first run, otherwise [home].
///
/// Keeps the decision in one place so `main` stays declarative.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    super.key,
    required this.home,
    this.store = const OnboardingStore(),
  });

  final Widget home;
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
      return OnboardingFlow(onDone: _finish);
    }
    return widget.home;
  }
}
