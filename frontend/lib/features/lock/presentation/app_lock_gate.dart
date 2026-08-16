import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_lock_store.dart';
import '../data/biometric_service.dart';
import 'lock_screen.dart';

/// Wraps the signed-in app and enforces the auto-lock session. While unlocked it
/// renders [child]; when the session expires (or on cold start with the lock on)
/// it renders the [LockScreen] until the user passes native biometric/PIN auth.
///
/// A single 1-second timer polls [AppLockStore.isLockedAt] against the wall
/// clock, plus a lifecycle observer re-checks on resume (a session can expire
/// while the app is backgrounded). The countdown ring elsewhere reads the same
/// store, so everything stays consistent.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final _store = AppLockStore.instance;
  Timer? _tick;
  bool _locked = false;
  bool _authInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store.addListener(_reevaluate);
    // Cold start: if the lock is on, we begin LOCKED (no live session yet). The
    // lock screen will prompt for auth on first frame.
    _locked = _store.isLockedAt(DateTime.now());
    // Poll every second so the session expiry flips us to locked promptly and
    // the (parent-owned) countdown ring stays in step.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _reevaluate());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _store.removeListener(_reevaluate);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the foreground: a session may have lapsed while we were
    // away — re-check immediately rather than waiting for the next tick.
    if (state == AppLifecycleState.resumed) _reevaluate();
  }

  void _reevaluate() {
    final nowLocked = _store.isLockedAt(DateTime.now());
    if (nowLocked != _locked && mounted) {
      setState(() => _locked = nowLocked);
    }
  }

  /// Run the native prompt. On success, start a fresh session (which unlocks).
  Future<void> _authenticate() async {
    if (_authInFlight) return;
    _authInFlight = true;
    try {
      final ok = await BiometricService.instance
          .authenticate(reason: 'Unlock Revora');
      if (ok) {
        _store.startSession(); // stamps a new deadline → isLockedAt() == false
        _reevaluate();
      }
    } finally {
      _authInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep [child] mounted underneath (its state/timers survive a lock) and lay
    // the lock screen over it when locked, so unlocking returns you exactly where
    // you were — no rebuild of the whole app.
    return Stack(
      children: [
        widget.child,
        if (_locked)
          Positioned.fill(
            child: LockScreen(onUnlock: _authenticate),
          ),
      ],
    );
  }
}
