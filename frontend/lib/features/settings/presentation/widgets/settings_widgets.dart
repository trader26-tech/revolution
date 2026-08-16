import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Reusable building blocks for the Settings page, all in the app's card style:
/// a titled section wrapping rows in one rounded card with hairline dividers.

/// A labelled group of rows rendered as a single rounded card.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    this.title,
    this.footnote,
    required this.children,
  });

  final String? title;
  final String? footnote;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              title!.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.inkFaint,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 56,
                    color: AppColors.hairline,
                  ),
                children[i],
              ],
            ],
          ),
        ),
        if (footnote != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              footnote!,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.inkFaint,
              ),
            ),
          ),
      ],
    );
  }
}

/// A single tappable settings row: leading icon, title, optional subtitle, and a
/// trailing value + chevron (or a custom trailing widget).
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.danger = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// A right-aligned value string (e.g. the current choice).
  final String? value;

  /// A custom trailing widget; overrides [value] + chevron when provided.
  final Widget? trailing;

  final VoidCallback? onTap;
  final Color? iconColor;
  final bool danger;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final tint = danger ? const Color(0xFFDC2626) : (iconColor ?? AppColors.accent);
    final titleColor = danger ? const Color(0xFFDC2626) : AppColors.ink;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            _IconChip(icon: icon, color: tint),
            const SizedBox(width: 14),
            // Title hugs its content; when there's no value the subtitle can
            // still take the rest of the row.
            Flexible(
              flex: value != null ? 0 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const Spacer(),
              trailing!,
            ] else ...[
              // The value fills the remaining space and sits hard RIGHT.
              if (value != null)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      value!,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                ),
              if (showChevron && onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.inkFaint, size: 22),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// A settings row with a trailing switch (for on/off preferences).
///
/// Clean by default: just the icon, title, and switch — NO always-on subtitle.
/// When [info] is set, a small ⓘ appears; tapping it (or the title) reveals a
/// one-line description inline, so the explanation is there on demand but never
/// clutters the row.
class SettingsSwitchTile extends StatefulWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    this.info,
    required this.value,
    required this.onChanged,
    this.iconColor,
  });

  final IconData icon;
  final String title;

  /// A one-line "what is this?" explanation, hidden until the user taps ⓘ.
  final String? info;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? iconColor;

  @override
  State<SettingsSwitchTile> createState() => _SettingsSwitchTileState();
}

class _SettingsSwitchTileState extends State<SettingsSwitchTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final hasInfo = widget.info != null && widget.info!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              _IconChip(icon: widget.icon, color: widget.iconColor ?? AppColors.accent),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: hasInfo ? () => setState(() => _open = !_open) : null,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (hasInfo) ...[
                        const SizedBox(width: 6),
                        _InfoDot(open: _open),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                value: widget.value,
                onChanged: widget.onChanged,
                activeTrackColor: AppColors.accent,
              ),
            ],
          ),
          if (hasInfo) _InfoReveal(open: _open, text: widget.info!),
        ],
      ),
    );
  }
}

/// The small ⓘ affordance beside a title — a quiet hint that a one-line
/// explanation is a tap away. Rotates to a downward chevron when open.
class _InfoDot extends StatelessWidget {
  const _InfoDot({required this.open});
  final bool open;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: open ? 0.5 : 0,
      duration: const Duration(milliseconds: 180),
      child: Icon(
        open ? Icons.expand_more_rounded : Icons.info_outline_rounded,
        size: 16,
        color: AppColors.inkFaint,
      ),
    );
  }
}

/// The inline description that expands under a row when its ⓘ is tapped.
class _InfoReveal extends StatelessWidget {
  const _InfoReveal({required this.open, required this.text});
  final bool open;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: open
          ? Padding(
              padding: const EdgeInsets.fromLTRB(48, 6, 8, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

/// The small rounded-square tinted icon holder used on every row.
class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }
}
