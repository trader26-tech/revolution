import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../home/home_page.dart';
import '../tasks/data/task_store.dart';
import '../update/data/update_service.dart';
import '../update/presentation/update_prompt.dart';

/// The app shell: a single Home destination.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.verified = true, this.onVerify});

  /// Whether the session is phone-verified. Kept for the auth gate's API even
  /// when the verify banner isn't currently rendered.
  final bool verified;

  /// Starts phone verification (opens the OTP flow). Null hides any prompt.
  final VoidCallback? onVerify;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // One shared task store so Home and Calendar stay in sync.
  final _store = TaskStore();

  @override
  void initState() {
    super.initState();
    // Restore saved tasks (and their icons) from on-device storage.
    _store.load();
    // Check for a newer app version on launch, and prompt (blocking if the
    // build is below the server's min-supported → mandatory update).
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  /// Ask the backend if a newer build exists. When one does, show the update
  /// prompt — dismissible for an optional update, non-dismissible (blocking)
  /// when it's forced, so every device converges on the latest version. Fails
  /// silently offline; it re-checks on the next launch.
  Future<void> _checkForUpdate() async {
    final info = await UpdateService.instance.check();
    if (!mounted || !info.available) return;
    await showUpdatePrompt(context, info);
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgTop, AppColors.bg],
          ),
        ),
        child: HomePage(store: _store),
      ),
    );
  }
}
