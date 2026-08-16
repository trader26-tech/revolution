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
  // Ordered dependency: establish the owner id, THEN let a saved session
  // override it — every later request is scoped to that number.
  await ApiClient.instance.init();
  await AuthStore.instance.load();

  // The remaining pre-UI stores touch disjoint prefs keys with no ordering
  // between them — load them concurrently instead of one-after-another so the
  // first frame isn't gated on the sum of their latencies.
  await Future.wait([
    OptionsStore.instance.load(), // saved lists / categories / payment methods
    ProfileStore.instance.load(), // name, notifications, defaults
    OnboardingStore.instance.load(), // whether the intro was completed
  ]);

  runApp(const RevolutionApp());

  // Deferred, off the first-frame path — neither is needed to draw the initial
  // screen, both are self-guarded (best-effort / no-op until ready):
  //   • CustomLogoStore.load() does a NETWORK call; its overrides are only read
  //     when the brand picker opens, and match() returns null gracefully until.
  //   • ReminderScheduler.init() is heavy (timezone db + native plugin); no
  //     notification is scheduled until TaskStore feeds tasks, and every
  //     consumer early-returns while it isn't ready.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    CustomLogoStore.instance.load();
    ReminderScheduler.instance.init();
  });
}

class RevolutionApp extends StatelessWidget {
  const RevolutionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // ONE global type-density knob: everything renders a touch smaller and
      // tighter across every screen, so more content fits and the app reads
      // compact-yet-professional — without hand-resizing each layout. We scale
      // DOWN by ~8%, then still clamp the user's system font setting so large
      // accessibility sizes can't blow the layouts up.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final base = media.textScaler.scale(1.0); // the user's chosen factor
        final compact = (base * 0.92).clamp(0.85, 1.08);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(compact)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      // The flow: Onboarding (first launch only) → Phone number → Home.
      // OnboardingGate shows the intro once, then hands off to AuthGate, which
      // requires phone login before revealing the app.
      home: const OnboardingGate(),
    );
  }
}
