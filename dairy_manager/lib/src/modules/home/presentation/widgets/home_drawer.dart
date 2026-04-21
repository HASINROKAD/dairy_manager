import 'package:flutter/material.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({
    super.key,
    required this.userName,
    required this.userId,
    required this.activeRole,
    this.isCustomerLinked = false,
    this.sellerCustomerCount,
    this.sellerWorkflowBadgeCount,
    this.customerDisputesBadgeCount,
    this.customerCorrectionsBadgeCount,
    required this.onProfileTap,
    required this.onLogoutTap,
    required this.onFeatureTap,
  });

  final String? userName;
  final String userId;
  final String activeRole;
  final bool isCustomerLinked;
  final int? sellerCustomerCount;
  final int? sellerWorkflowBadgeCount;
  final int? customerDisputesBadgeCount;
  final int? customerCorrectionsBadgeCount;
  final VoidCallback onProfileTap;
  final VoidCallback onLogoutTap;
  final void Function(String featureKey) onFeatureTap;

  Widget _drawerActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    int? badgeCount,
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
              if (badgeCount != null) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
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
        ? <({String key, String title, IconData icon, int? badgeCount})>[
            (
              key: 'seller_milk_settings',
              title: 'Milk Settings',
              icon: Icons.tune_rounded,
              badgeCount: null,
            ),
            (
              key: 'seller_routes',
              title: 'Delivery Routes',
              icon: Icons.route_outlined,
              badgeCount: null,
            ),
            (
              key: 'seller_requests',
              title: 'Join Requests',
              icon: Icons.group_add_rounded,
              badgeCount: null,
            ),
            (
              key: 'seller_issues',
              title: 'Delivery Issues',
              icon: Icons.report_problem_outlined,
              badgeCount: null,
            ),
            (
              key: 'seller_pauses',
              title: 'Delivery Pauses',
              icon: Icons.pause_circle_outline,
              badgeCount: null,
            ),
            (
              key: 'seller_billing',
              title: 'Billing',
              icon: Icons.receipt_long_outlined,
              badgeCount: null,
            ),
            (
              key: 'seller_workflows',
              title: 'Disputes & Corrections',
              icon: Icons.rule_rounded,
              badgeCount: sellerWorkflowBadgeCount,
            ),
            (
              key: 'seller_audit',
              title: 'Audit Timeline',
              icon: Icons.history_rounded,
              badgeCount: null,
            ),
          ]
        : <({String key, String title, IconData icon, int? badgeCount})>[
            if (!isCustomerLinked)
              (
                key: 'customer_join',
                title: 'Nearby Sellers',
                icon: Icons.storefront_outlined,
                badgeCount: null,
              ),
            (
              key: 'customer_issues',
              title: 'Report Issues',
              icon: Icons.report_problem_outlined,
              badgeCount: null,
            ),
            (
              key: 'customer_pauses',
              title: 'Pause/Resume',
              icon: Icons.pause_circle_outline,
              badgeCount: null,
            ),
            (
              key: 'customer_billing',
              title: 'Billing',
              icon: Icons.receipt_long_outlined,
              badgeCount: null,
            ),
            (
              key: 'customer_disputes',
              title: 'My Disputes',
              icon: Icons.gavel_rounded,
              badgeCount: customerDisputesBadgeCount,
            ),
            (
              key: 'customer_corrections',
              title: 'Correction Requests',
              icon: Icons.fact_check_outlined,
              badgeCount: customerCorrectionsBadgeCount,
            ),
            (
              key: 'customer_audit',
              title: 'Audit Timeline',
              icon: Icons.history_rounded,
              badgeCount: null,
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
                badgeCount: item.badgeCount,
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
