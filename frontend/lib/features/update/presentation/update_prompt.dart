import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../data/update_service.dart';

/// Presents the "Update available" prompt for [info].
///
///  * Optional update → a dismissible bottom sheet ("Later" / "Update").
///  * Forced update (installed build below min-supported) → a non-dismissible
///    blocking dialog; the only way out is to update.
///
/// "Update" opens the APK download URL in the browser; Android downloads it and
/// the user installs it via the usual "install app" flow.
Future<void> showUpdatePrompt(BuildContext context, UpdateInfo info) {
  if (!info.available) return Future.value();
  return showDialog<void>(
    context: context,
    barrierDismissible: !info.forced,
    builder: (_) => _UpdateDialog(info: info),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({required this.info});
  final UpdateInfo info;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _opening = false;

  Future<void> _update() async {
    setState(() => _opening = true);
    final ok = await launchUrl(
      Uri.parse(widget.info.apkUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      setState(() => _opening = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the download link.")),
      );
    }
    // On success the browser takes over; leave the dialog as-is (forced) or the
    // user can dismiss (optional).
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final notes = info.notes.trim();

    return PopScope(
      canPop: !info.forced, // forced updates can't be back-dismissed
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.system_update_rounded,
              color: AppColors.accent, size: 30),
        ),
        title: Text(
          info.forced ? 'Update required' : 'Update available',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              info.forced
                  ? 'A newer version is required to keep using the app.'
                  : 'A newer version is ready with the latest features.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(14),
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
                    const SizedBox(height: 6),
                    Text(
                      notes,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _opening ? null : _update,
                  child: _opening
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Colors.white),
                        )
                      : const Text('Update now'),
                ),
              ),
              if (!info.forced)
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.inkFaint,
                  ),
                  child: const Text('Later'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
