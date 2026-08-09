import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';

/// A tap-to-pick LOCAL image field. Picks an image from the device, keeps its
/// on-device path (no upload), and shows a preview. Used for the birthday
/// person's face (circular) and the subscription picture (rounded square).
///
/// Purely local: hands the chosen file path back via [onChanged]. The caller
/// stores it on the Task's `imagePath`.
class LocalPhotoField extends StatelessWidget {
  const LocalPhotoField({
    super.key,
    required this.path,
    required this.accent,
    required this.onChanged,
    this.circular = false,
    this.label = 'Add a photo',
    this.size = 96,
  });

  /// The current local file path, or null when none picked yet.
  final String? path;
  final Color accent;
  final ValueChanged<String?> onChanged;

  /// Circular (a face) vs rounded-square (a subscription picture).
  final bool circular;
  final String label;
  final double size;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false, // we keep the on-device path, no bytes/upload
    );
    final picked = result?.files.firstOrNull;
    if (picked?.path != null) {
      HapticFeedback.selectionClick();
      onChanged(picked!.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = circular ? size : 22.0;
    final has = path != null && path!.isNotEmpty;

    return Row(
      children: [
        GestureDetector(
          onTap: _pick,
          child: Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: has ? accent : AppColors.cardBorder,
                width: has ? 1.6 : 1,
              ),
              boxShadow: has
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: has
                ? Image.file(File(path!), fit: BoxFit.cover)
                : Icon(circular ? Icons.person_rounded : Icons.image_rounded,
                    color: accent, size: size * 0.38),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _pick,
                child: Text(
                  has ? 'Change photo' : label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                has ? 'Stored on this device' : 'Optional — makes it personal',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkFaint,
                ),
              ),
              if (has) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(null);
                  },
                  child: const Text(
                    'Remove',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
