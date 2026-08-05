import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_page.dart';

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
      home: const HomePage(),
    );
  }
}
