import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/options/data/options_store.dart';
import 'features/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Establish the owner id used on every server request.
  await ApiClient.instance.init();
  // Load the user's saved lists / categories / payment methods before the UI.
  await OptionsStore.instance.load();
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
      home: const AppShell(),
    );
  }
}
