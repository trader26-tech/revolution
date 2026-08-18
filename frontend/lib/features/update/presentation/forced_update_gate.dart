import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/play_update_service.dart';

/// A full-screen, UNESCAPABLE gate shown when the server marks this build as
/// below the mandatory minimum AND Play's own blocking flow didn't complete
/// (user dismissed it, or Play can't service it yet). While this is up, NONE of
/// the app is reachable — it sits above everything, has no back-out, and its
/// only action retries the Play update. This is what makes "you can't use the
/// app until you update" literally true.
class ForcedUpdateGate extends StatefulWidget {
  const ForcedUpdateGate({super.key, this.notes = ''});

  /// Optional "what's new" text from the backend.
  final String notes;

  @override
  State<ForcedUpdateGate> createState() => _ForcedUpdateGateState();
}

class _ForcedUpdateGateState extends State<ForcedUpdateGate> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    // Re-run the immediate Play update. On success the app restarts into the new
    // build; otherwise we stay gated and let the user try again.
    await PlayUpdateService.instance.run(forced: true);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.notes.trim();
    // Block system back entirely — there is no way past this screen but to update.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.bgTop, AppColors.bg],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.system_update_rounded,
                        color: AppColors.accent, size: 38),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Update required',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A newer version is required to keep using the app. '
                    'Please update to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "WHAT'S NEW",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: AppColors.inkFaint,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            notes,
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _retry,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Update now'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
