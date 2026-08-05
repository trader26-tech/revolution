import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/home/presentation/home_page.dart';
import 'features/onboarding/presentation/onboarding_gate.dart';

void main() {
  runApp(const RevolutionApp());
}

class RevolutionApp extends StatelessWidget {
  const RevolutionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Phone login gates the whole app. Once signed in, the user's id scopes
      // onboarding and every reminder to their own account.
      home: AuthGate(
        builder: (context, session, onSignOut) => OnboardingGate(
          ownerId: session.userId,
          home: HomePage(ownerId: session.userId, onSignOut: onSignOut),
        ),
      ),
    );
  }
}
