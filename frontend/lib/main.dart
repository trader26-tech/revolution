import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_store.dart';
import 'features/brand/data/custom_logo_store.dart';
import 'features/onboarding/data/onboarding_store.dart';
import 'features/onboarding/presentation/onboarding_gate.dart';
import 'features/options/data/options_store.dart';
import 'features/reminders/data/reminder_scheduler.dart';
import 'features/settings/data/profile_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Boot Firebase (phone/OTP auth). Guarded so a misconfigured/absent native
  // config degrades to "can't verify" instead of crashing the whole app.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init failed: $e');
  }
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
  // Whether the one-time onboarding intro has been completed.
  await OnboardingStore.instance.load();
  // Set up the daily-summary notification machinery (timezones, channels,
  // tray actions). Must run before TaskStore starts feeding it task changes.
  await ReminderScheduler.instance.init();
  runApp(const RevolutionApp());
}

class RevolutionApp extends StatelessWidget {
  const RevolutionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Revolution',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // The flow: Onboarding (first launch only) → Phone number → Home.
      // OnboardingGate shows the intro once, then hands off to AuthGate, which
      // requires phone login before revealing the app.
      home: const OnboardingGate(),
    );
  }
}
