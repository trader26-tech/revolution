import 'package:flutter/material.dart';

import '../../../core/theme/bamboo_palette.dart';
import '../../family/presentation/family_page.dart';

/// The Account tab.
///
/// NOTE: the full account/settings experience is owned by another agent. This
/// is a clean, working hub — profile header, a link to the Family screen that
/// agent's teammate built, and sign-out — so the third nav slot is functional
/// today. Extend or replace the body as the account work lands; the nav slot,
/// [ownerId], and [onSignOut] wiring are already in place.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.ownerId, this.onSignOut});

  final String ownerId;
  final VoidCallback? onSignOut;

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You can sign back in any time with your phone number.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok == true) onSignOut?.call();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Bamboo.mist, Bamboo.cream, Bamboo.creamHi],
          stops: [0.0, 0.4, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
          children: [
            Text(
              'Account',
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: Bamboo.ink,
              ),
            ),
            const SizedBox(height: 16),
            _Tile(
              icon: Icons.group_rounded,
              title: 'Family members',
              subtitle: 'Manage who you track renewals for',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FamilyPage(ownerId: ownerId),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _Tile(
              icon: Icons.person_outline_rounded,
              title: 'Profile details',
              subtitle: 'Coming soon',
              enabled: false,
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _Tile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              subtitle: 'Coming soon',
              enabled: false,
              onTap: () {},
            ),
            const SizedBox(height: 24),
            if (onSignOut != null)
              OutlinedButton.icon(
                onPressed: () => _confirmSignOut(context),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE5484D),
                  side: const BorderSide(color: Color(0x33E5484D)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Bamboo.card,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Bamboo.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Bamboo.sprout.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Bamboo.greenDeep),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Bamboo.ink,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(color: Bamboo.inkSoft),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  const Icon(Icons.chevron_right_rounded,
                      color: Bamboo.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
