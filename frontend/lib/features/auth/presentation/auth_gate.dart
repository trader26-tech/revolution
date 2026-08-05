import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../data/auth_store.dart';
import 'phone_login_page.dart';

/// The top-level gate: nothing in the app is reachable without a phone login.
///
/// - No stored session  → show [PhoneLoginPage].
/// - Session present    → build the app via [builder], handing it the signed-in
///   user id (used as X-Owner-Id) and a sign-out callback.
///
/// This is deliberately above onboarding, so switching accounts (sign out →
/// log in with another number) swaps the whole data scope cleanly.
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.builder,
    this.repository,
  });

  /// Builds the authenticated app. `onSignOut` returns the user to login.
  final Widget Function(
    BuildContext context,
    AuthSession session,
    VoidCallback onSignOut,
  ) builder;

  final AuthRepository? repository;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthRepository _auth = widget.repository ?? AuthRepository();

  AuthSession? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final session = await _auth.currentSession();
    if (!mounted) return;
    setState(() {
      _session = session;
      _loading = false;
    });
  }

  void _onLoggedIn(AuthSession session) {
    setState(() => _session = session);
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = _session;
    if (session == null) {
      return PhoneLoginPage(repository: _auth, onLoggedIn: _onLoggedIn);
    }
    // Key on the user id so switching accounts rebuilds the whole subtree
    // (fresh onboarding check, fresh data) instead of reusing stale state.
    return KeyedSubtree(
      key: ValueKey(session.userId),
      child: widget.builder(context, session, _signOut),
    );
  }
}
