import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../data/app_lock_store.dart';

/// The countdown pill shown at the top of Home while the App Lock is on: a small
/// circular progress ring (draining as the session runs down) + the remaining
/// time as "M:SS". Tap it to open the "Auto-lock after" sheet — presets + a
/// manual minute entry + "Lock now" — mirroring the design mock.
///
/// Renders nothing when the lock is disabled or there's no live session.
class LockTimerPill extends StatefulWidget {
  const LockTimerPill({super.key});

  @override
  State<LockTimerPill> createState() => _LockTimerPillState();
}

class _LockTimerPillState extends State<LockTimerPill> {
  final _store = AppLockStore.instance;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // 1s repaint so the ring + digits count down smoothly.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _store.addListener(_onStore);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _store.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  String _fmt(Duration d) {
    final total = d.inSeconds;
    final m = total ~/ 60;
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_store.enabled) return const SizedBox.shrink();
    final now = DateTime.now();
    final remaining = _store.remainingAt(now);
    if (remaining == Duration.zero) return const SizedBox.shrink();

    final total = _store.sessionLength.inSeconds;
    final progress =
        total == 0 ? 0.0 : (remaining.inSeconds / total).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showAutoLockSheet(context);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 2.6,
                      backgroundColor: AppColors.cardBorder,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 9),
            Text(
              _fmt(remaining),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                fontFeatures: [FontFeature.tabularFigures()],
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Open the "Auto-lock after" bottom sheet — presets, a manual minute stepper,
/// and "Lock now" — reading/writing [AppLockStore].
void showAutoLockSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => const _AutoLockSheet(),
  );
}

class _AutoLockSheet extends StatefulWidget {
  const _AutoLockSheet();

  @override
  State<_AutoLockSheet> createState() => _AutoLockSheetState();
}

class _AutoLockSheetState extends State<_AutoLockSheet> {
  final _store = AppLockStore.instance;
  late final TextEditingController _manualCtrl;

  @override
  void initState() {
    super.initState();
    _manualCtrl = TextEditingController(text: _store.minutes.toString());
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  void _apply(int m) {
    final clamped = m.clamp(AppLockStore.minMinutes, AppLockStore.maxMinutes);
    HapticFeedback.selectionClick();
    _store.setMinutes(clamped);
    _manualCtrl.text = clamped.toString();
    setState(() {});
  }

  void _step(int delta) {
    final cur = int.tryParse(_manualCtrl.text) ?? _store.minutes;
    _manualCtrl.text =
        (cur + delta).clamp(AppLockStore.minMinutes, AppLockStore.maxMinutes).toString();
    setState(() {});
  }

  String _label(int m) => m == 60 ? '1h' : '${m}m';

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final selected = _store.minutes;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1.2)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      'Auto-lock after',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$selected min',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Presets.
                Row(
                  children: [
                    for (final m in AppLockStore.presets) ...[
                      Expanded(
                        child: _PresetChip(
                          label: _label(m),
                          selected: m == selected,
                          onTap: () => _apply(m),
                        ),
                      ),
                      if (m != AppLockStore.presets.last)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                // Manual entry + Set.
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _manualCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                cursorColor: AppColors.accent,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _StepArrow(
                                    icon: Icons.keyboard_arrow_up_rounded,
                                    onTap: () => _step(1)),
                                _StepArrow(
                                    icon: Icons.keyboard_arrow_down_rounded,
                                    onTap: () => _step(-1)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('min',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        )),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () {
                        final m = int.tryParse(_manualCtrl.text);
                        if (m != null) _apply(m);
                      },
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: [AppColors.accent, AppColors.accentDeep],
                          ),
                        ),
                        child: const Text('Set',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            )),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Lock now.
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _store.lockNow();
                    Navigator.of(context).pop();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded,
                            size: 18, color: AppColors.inkSoft),
                        SizedBox(width: 8),
                        Text('Lock now',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkSoft,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: selected
              ? const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentDeep])
              : null,
          color: selected ? null : AppColors.bg,
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _StepArrow extends StatelessWidget {
  const _StepArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 16,
        width: 22,
        child: Icon(icon, size: 18, color: AppColors.inkSoft),
      ),
    );
  }
}
