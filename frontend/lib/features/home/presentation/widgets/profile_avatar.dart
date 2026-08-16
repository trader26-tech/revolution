import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../lock/presentation/lock_timer_pill.dart' show showAutoLockSheet;
import '../../../settings/data/profile_store.dart';

/// The user's PROFILE PHOTO, shown as a round avatar beside the home greeting.
/// Tap to add a photo (or change/remove an existing one) — picked from the
/// device and stored on-device via [ProfileStore.setAvatarFromPath]. Listens to
/// [ProfileStore] so it updates the instant the photo changes.
///
/// Empty state: a soft glass circle with a person glyph + a small "+" badge, so
/// it clearly reads as "tap to add your photo".
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.size = 46});

  final double size;

  Future<void> _pick(BuildContext context) async {
    final store = ProfileStore.instance;
    // Always show the menu: photo actions (add / change + remove) PLUS the
    // auto-lock timer control, so the timer is reachable from the avatar again.
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            _sheetTile(
                ctx,
                Icons.photo_camera_rounded,
                store.hasAvatar ? 'Change photo' : 'Add photo',
                'change'),
            if (store.hasAvatar)
              _sheetTile(ctx, Icons.delete_outline_rounded, 'Remove photo',
                  'remove', danger: true),
            // The auto-lock timer control — set how long the app stays unlocked.
            _sheetTile(ctx, Icons.lock_clock_rounded, 'Auto-lock timer', 'timer'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!context.mounted) return;
    if (action == 'timer') {
      HapticFeedback.selectionClick();
      showAutoLockSheet(context);
      return;
    }
    if (action == 'remove') {
      HapticFeedback.selectionClick();
      await store.setAvatarFromPath(null);
      return;
    }
    if (action != 'change') return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false,
    );
    final picked = result?.files.firstOrNull;
    if (picked?.path != null) {
      HapticFeedback.selectionClick();
      await store.setAvatarFromPath(picked!.path);
    }
  }

  Widget _sheetTile(BuildContext ctx, IconData icon, String label, String value,
      {bool danger = false}) {
    final color = danger ? const Color(0xFFFF6B6B) : AppColors.ink;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      onTap: () => Navigator.of(ctx).pop(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ProfileStore.instance,
      builder: (context, _) {
        final path = ProfileStore.instance.avatarPath;
        final has = path != null;
        return GestureDetector(
          onTap: () => _pick(context),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // The avatar circle — photo, or a glass placeholder.
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: has ? 0.55 : 0.3),
                      width: 1.5,
                    ),
                    boxShadow: has
                        ? [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                    image: has
                        ? DecorationImage(
                            image: FileImage(File(path)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: has
                      ? null
                      : Icon(Icons.person_rounded,
                          size: size * 0.5,
                          color: AppColors.inkSoft.withValues(alpha: 0.9)),
                ),
                // (No "+" badge — the avatar is still tappable to add/change a
                // photo, but the plus overlay was visual clutter.)
              ],
            ),
          ),
        );
      },
    );
  }
}
