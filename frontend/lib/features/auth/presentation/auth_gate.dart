import 'package:flutter/material.dart';

import '../../shell/app_shell.dart';
import '../data/auth_store.dart';
import 'phone_login_page.dart';

/// Decides the first screen based on sign-in state:
///   • logged in  → the app ([AppShell])
///   • logged out → the phone login page
///
/// Logging in remembers the number, so future launches skip straight to the
/// app until sign-out. Designed to sit AFTER onboarding — a parallel onboarding
/// flow can render this once its intro is done.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.store});

  final AuthStore? store;

  @override
  Widget build(BuildContext context) {
    final auth = store ?? AuthStore.instance;
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        if (auth.isLoggedIn) return const AppShell();
        return PhoneLoginPage(onSubmit: auth.login);
      },
    );
  }
}
