import 'package:flutter/material.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({
    super.key,
    required this.userName,
    required this.userId,
    required this.activeRole,
    required this.onProfileTap,
    required this.onLogoutTap,
    required this.onFeatureTap,
  });

  final String? userName;
  final String userId;
  final String activeRole;
  final VoidCallback onProfileTap;
  final VoidCallback onLogoutTap;
  final void Function(String featureKey) onFeatureTap;

  Widget _drawerActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
            ),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalizedRole = activeRole.trim().toLowerCase();
    final featureShortcuts = normalizedRole == 'seller'
        ? const <({String key, String title, IconData icon})>[
            (
              key: 'seller_issues',
              title: 'Delivery Issues',
              icon: Icons.report_problem_outlined,
            ),
            (
              key: 'seller_pauses',
              title: 'Delivery Pauses',
              icon: Icons.pause_circle_outline,
            ),
          ]
        : const <({String key, String title, IconData icon})>[
            (
              key: 'customer_issues',
              title: 'Report Issues',
              icon: Icons.report_problem_outlined,
            ),
            (
              key: 'customer_pauses',
              title: 'Pause/Resume',
              icon: Icons.pause_circle_outline,
            ),
          ];

    return Drawer(
      width: 286,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.35),
                ),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    child: Text(
                      ((userName ?? '').trim().isEmpty
                              ? 'U'
                              : (userName!.trim().characters.first))
                          .toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (userName ?? '').trim().isEmpty
                              ? 'User'
                              : userName!.trim(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _drawerActionTile(
              context: context,
              icon: Icons.person_outline_rounded,
              title: 'Profile',
              onTap: onProfileTap,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Shortcuts',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 4),
            ...featureShortcuts.map(
              (item) => _drawerActionTile(
                context: context,
                icon: item.icon,
                title: item.title,
                onTap: () => onFeatureTap(item.key),
              ),
            ),
            _drawerActionTile(
              context: context,
              icon: Icons.logout_rounded,
              title: 'Logout',
              onTap: onLogoutTap,
            ),
            const Spacer(),
            Opacity(
              opacity: 0.5,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Active role: ${activeRole.toUpperCase()}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Opacity(
                      opacity: 0.45,
                      child: Text(
                        'ID: $userId',
                        style: const TextStyle(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
