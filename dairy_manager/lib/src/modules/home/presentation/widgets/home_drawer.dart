import 'package:flutter/material.dart';

class _AutoMarqueeText extends StatefulWidget {
  const _AutoMarqueeText({
    required this.text,
    required this.style,
  });

  static const Duration _pauseDuration = Duration(milliseconds: 900);

  final String text;
  final TextStyle style;

  @override
  State<_AutoMarqueeText> createState() => _AutoMarqueeTextState();
}

class _AutoMarqueeTextState extends State<_AutoMarqueeText> {
  final ScrollController _scrollController = ScrollController();
  int _loopToken = 0;
  double? _lastWidth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureAndAnimateIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant _AutoMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _measureAndAnimateIfNeeded(forceRestart: true);
      });
    }
  }

  @override
  void dispose() {
    _loopToken++;
    _scrollController.dispose();
    super.dispose();
  }

  void _measureAndAnimateIfNeeded({bool forceRestart = false}) {
    if (!mounted) {
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    final maxWidth = renderBox?.size.width;
    if (maxWidth == null || maxWidth <= 0) {
      return;
    }

    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);

    final maxScrollExtent = (textPainter.width - maxWidth).clamp(
      0,
      double.infinity,
    );
    if (maxScrollExtent <= 1) {
      _loopToken++;
      if (_scrollController.hasClients && _scrollController.offset != 0) {
        _scrollController.jumpTo(0);
      }
      return;
    }

    if (!forceRestart && _lastWidth == maxWidth) {
      return;
    }

    _lastWidth = maxWidth;
    final token = ++_loopToken;
    _runMarqueeLoop(token, maxScrollExtent.toDouble());
  }

  Future<void> _runMarqueeLoop(int token, double maxScrollExtent) async {
    await Future<void>.delayed(_AutoMarqueeText._pauseDuration);

    while (mounted && token == _loopToken) {
      if (!_scrollController.hasClients) {
        return;
      }

      final travelMs = (maxScrollExtent * 20).round().clamp(1800, 7000);
      final travelDuration = Duration(milliseconds: travelMs);

      await _scrollController.animateTo(
        maxScrollExtent,
        duration: travelDuration,
        curve: Curves.linear,
      );

      if (!mounted || token != _loopToken) {
        return;
      }
      await Future<void>.delayed(_AutoMarqueeText._pauseDuration);

      if (!_scrollController.hasClients) {
        return;
      }

      await _scrollController.animateTo(
        0,
        duration: travelDuration,
        curve: Curves.linear,
      );

      if (!mounted || token != _loopToken) {
        return;
      }
      await Future<void>.delayed(_AutoMarqueeText._pauseDuration);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _measureAndAnimateIfNeeded();
        });

        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Text(widget.text, style: widget.style, softWrap: false),
        );
      },
    );
  }
}

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
              Expanded(
                child: SizedBox(
                  height: 24,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _AutoMarqueeText(
                      text: title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
