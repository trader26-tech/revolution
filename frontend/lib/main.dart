import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_store.dart';
import 'features/brand/data/custom_logo_store.dart';
import 'features/onboarding/data/onboarding_store.dart';
import 'features/onboarding/presentation/onboarding_gate.dart';
import 'features/options/data/options_store.dart';
import 'features/settings/data/profile_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Establish the owner id used on every server request.
  await ApiClient.instance.init();
  // Restore a signed-in session (the phone number → API owner id), if any. This
  // may override the owner id set above, scoping data to the logged-in number.
  await AuthStore.instance.load();
  // Load the user's saved lists / categories / payment methods before the UI.
  await OptionsStore.instance.load();
  // Load manually-curated brand logos (override the auto-resolver). Best-effort.
  await CustomLogoStore.instance.load();
  // Load the user's personal preferences (name, notifications, defaults).
  await ProfileStore.instance.load();
  runApp(const RevolutionApp());
}

class RevolutionApp extends StatelessWidget {
  const RevolutionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Revolution',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // AuthGate: phone login when logged out, the app when logged in. When the
      // parallel onboarding flow lands, wrap this (e.g. OnboardingGate(AuthGate)).
      home: const AuthGate(),
    );
  }
}
