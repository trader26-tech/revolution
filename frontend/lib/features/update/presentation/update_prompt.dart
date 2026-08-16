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
  /// null = idle; otherwise a download is in flight (0→1, or null = started but
  /// size unknown, shown as an indeterminate bar).
  double? _progress;
  bool _busy = false;

  /// Download the APK IN-APP and hand it to Android's installer. Shows live
  /// progress; on any failure, falls back to opening the link in the browser so
  /// the update path is never a dead end.
  Future<void> _update() async {
    setState(() {
      _busy = true;
      _progress = 0;
    });
    final result = await UpdateService.instance.downloadAndInstall(
      widget.info.apkUrl,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    if (result == InstallResult.launched) {
      // Android's install screen is up. Leave the dialog (forced stays blocking;
      // optional lets them dismiss).
      setState(() => _busy = false);
      return;
    }
    // Download/hand-off failed → fall back to the browser link.
    final ok = await launchUrl(
      Uri.parse(widget.info.apkUrl),
      mode: LaunchMode.externalApplication,
    );
    if (mounted) {
      setState(() {
        _busy = false;
        _progress = null;
      });
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't download the update.")),
        );
      }
    }
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
                  onPressed: _busy ? null : _update,
                  child: _busy
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                                // Determinate once we know the size, else spin.
                                value: _progress,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _progress == null
                                  ? 'Downloading…'
                                  : 'Downloading ${(_progress! * 100).round()}%',
                            ),
                          ],
                        )
                      : const Text('Update now'),
                ),
              ),
              if (!info.forced && !_busy)
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
