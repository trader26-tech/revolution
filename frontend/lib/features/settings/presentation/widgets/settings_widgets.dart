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

/// A single settings row: leading icon, title, and a trailing value + chevron
/// (or a custom trailing widget), pinned RIGHT.
///
/// Clean by default — NO always-on subtitle, NO ⓘ button. When [info] is set,
/// tapping the row's own LEADING ICON reveals a one-line description inline (the
/// icon IS the "what is this?" affordance). Rows that DO something on tap
/// ([onTap]) keep that as their main action; only the icon toggles info.
class SettingsTile extends StatefulWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.info,
    this.value,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.danger = false,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;

  /// A one-line "what is this?" explanation, hidden until the user taps ⓘ.
  final String? info;

  /// A right-aligned value string (e.g. the current choice).
  final String? value;

  /// A custom trailing widget; overrides [value] + chevron when provided.
  final Widget? trailing;

  final VoidCallback? onTap;
  final Color? iconColor;
  final bool danger;
  final bool showChevron;

  @override
  State<SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<SettingsTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final tint = widget.danger
        ? const Color(0xFFDC2626)
        : (widget.iconColor ?? AppColors.accent);
    final titleColor = widget.danger ? const Color(0xFFDC2626) : AppColors.ink;
    final hasInfo = widget.info != null && widget.info!.trim().isNotEmpty;

    // The leading icon IS the info affordance — tapping it reveals the one-liner.
    Widget leading = _IconChip(icon: widget.icon, color: tint);
    if (hasInfo) {
      leading = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _open = !_open),
        child: leading,
      );
    }

    final titleText = Text(
      widget.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        color: titleColor,
      ),
    );

    return Column(
      children: [
        InkWell(
          // The whole row runs its action; when there's no action, tapping it
          // toggles the info (same as the icon).
          onTap: widget.onTap ??
              (hasInfo ? () => setState(() => _open = !_open) : null),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 14),
                // Title takes the slack so every trailing control is pinned RIGHT.
                Expanded(child: titleText),
                if (widget.trailing != null)
                  widget.trailing!
                else ...[
                  if (widget.value != null)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          widget.value!,
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
                  if (widget.showChevron && widget.onTap != null) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.inkFaint, size: 22),
                  ],
                ],
              ],
            ),
          ),
        ),
        if (hasInfo)
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 14),
            child: _InfoReveal(open: _open, text: widget.info!),
          ),
      ],
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
              // The leading icon IS the info affordance — tap it to reveal the
              // one-liner. No separate ⓘ.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: hasInfo ? () => setState(() => _open = !_open) : null,
                child: _IconChip(
                    icon: widget.icon,
                    color: widget.iconColor ?? AppColors.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: hasInfo ? () => setState(() => _open = !_open) : null,
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // The switch, pinned RIGHT.
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

/// The inline description that expands under a row when its icon is tapped.
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
