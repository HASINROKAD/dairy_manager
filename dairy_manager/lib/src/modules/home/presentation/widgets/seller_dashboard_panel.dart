import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/home_repository.dart';
import '../../../milk/milk_barrel.dart';

class SellerDashboardPanel extends StatefulWidget {
  const SellerDashboardPanel({
    super.key,
    required this.repository,
    this.refreshSignal = 0,
  });

  final MilkRepository repository;
  final int refreshSignal;

  @override
  State<SellerDashboardPanel> createState() => _SellerDashboardPanelState();
}

class _SellerDashboardPanelState extends State<SellerDashboardPanel> {
  late final DeliveryBloc _deliveryBloc;
  late final HomeRepository _homeRepository;
  List<Map<String, dynamic>> _pausedItems = const <Map<String, dynamic>>[];
  bool _loadingPausedItems = true;
  String? _pausedItemsError;

  @override
  void initState() {
    super.initState();
    _homeRepository = HomeRepository();
    _deliveryBloc = DeliveryBloc(repository: widget.repository)
      ..add(const LoadDailySheet());
    _loadPausedItems();
  }

  @override
  void dispose() {
    _deliveryBloc.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SellerDashboardPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshSignal != oldWidget.refreshSignal) {
      _deliveryBloc.add(const LoadDailySheet());
      _loadPausedItems();
    }
  }

  Future<void> _loadPausedItems() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _loadingPausedItems = true;
      _pausedItemsError = null;
    });

    try {
      final items = await _homeRepository.fetchSellerDeliveryPauses();
      if (!mounted) {
        return;
      }

      setState(() {
        _pausedItems = items;
        _loadingPausedItems = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _pausedItems = const <Map<String, dynamic>>[];
        _pausedItemsError = error.toString();
        _loadingPausedItems = false;
      });
    }
  }

  String _distanceLabel(DeliverySheetItem item) {
    final routeLabel = (item.routeDistanceLabel ?? '').toLowerCase();
    final routeReason = (item.routeDistanceReason ?? '').toLowerCase();
    if (routeLabel.contains('straight-line') ||
        routeReason.contains('straight-line')) {
      return 'Road route unavailable';
    }

    if (item.routeDistanceKm == null) {
      return 'Road route unavailable';
    }

    if (item.routeDistanceMeters != null && item.routeDistanceMeters! < 1000) {
      return 'Road route: ${item.routeDistanceMeters} m';
    }

    return 'Road route: ${item.routeDistanceKm!.toStringAsFixed(2)} km';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DeliveryBloc>.value(
      value: _deliveryBloc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlocBuilder<DeliveryBloc, DeliveryState>(
            builder: (context, state) {
              if (state.status == DeliveryStatus.loading &&
                  state.items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.status == DeliveryStatus.failure &&
                  state.items.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.errorMessage ?? 'Could not load daily sheet.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        context.read<DeliveryBloc>().add(
                          const LoadDailySheet(),
                        );
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (state.items.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'No assigned customers found for route planning.',
                      ),
                    )
                  else
                    ...state.items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final distanceLabel = _distanceLabel(item);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.22),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).colorScheme.shadow.withValues(alpha: 0.06),
                              blurRadius: 18,
                              spreadRadius: -12,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      _SellerCustomerLegalInfoPage(item: item),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 36,
                                    width: 36,
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.customerName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (item.customerDisplayAddress
                                                ?.trim()
                                                .isNotEmpty ==
                                            true) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            item.customerDisplayAddress!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.surfaceContainerLow,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            distanceLabel,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                  Text(
                    'Paused Customers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_loadingPausedItems)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if ((_pausedItemsError ?? '').trim().isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pausedItemsError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _loadPausedItems,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    )
                  else if (_pausedItems.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('No customers are currently paused.'),
                    )
                  else
                    ..._pausedItems.map((pause) {
                      final name = (pause['customerName']?.toString() ?? '')
                          .trim();
                      final phone = (pause['customerPhone']?.toString() ?? '')
                          .trim();
                      final address =
                          (pause['customerDisplayAddress']?.toString() ?? '')
                              .trim();
                      final quantity =
                          (pause['customerDefaultQuantityLitres'] as num?)
                              ?.toDouble();
                      final start = (pause['startDateKey']?.toString() ?? '-')
                          .trim();
                      final end = (pause['endDateKey']?.toString() ?? '-')
                          .trim();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant
                                .withValues(alpha: 0.55),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name.isEmpty ? 'Customer' : name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Pause: $start to $end'),
                              if (phone.isNotEmpty) Text('Phone: $phone'),
                              if (address.isNotEmpty) Text('Address: $address'),
                              if (quantity != null)
                                Text(
                                  'Daily quantity impact: ${quantity.toStringAsFixed(2)} L',
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'Paused by customer',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SellerCustomerLegalInfoPage extends StatelessWidget {
  const _SellerCustomerLegalInfoPage({required this.item});

  final DeliverySheetItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final distanceLabel = _buildDistanceLabel();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Information'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.surface,
                  colorScheme.surfaceContainerLowest,
                  colorScheme.secondaryContainer.withValues(alpha: 0.24),
                ],
                stops: const [0.0, 0.48, 1.0],
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.92),
                      colorScheme.tertiary.withValues(alpha: 0.84),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.customerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (distanceLabel.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _metaChip(
                        icon: Icons.route_rounded,
                        label: distanceLabel,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.08),
                      blurRadius: 20,
                      spreadRadius: -10,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _infoTile(
                      context,
                      icon: Icons.badge_outlined,
                      label: 'Customer ID',
                      value: item.customerId,
                    ),
                    _infoTile(
                      context,
                      icon: Icons.calendar_month_outlined,
                      label: 'Joining Date',
                      value: _formatJoinedDate(item.organizationJoinedAt),
                    ),
                    _infoTile(
                      context,
                      icon: Icons.phone_outlined,
                      label: 'Mobile',
                      value: _displayOrDash(item.mobileNumber),
                    ),
                    _infoTile(
                      context,
                      icon: Icons.alternate_email_rounded,
                      label: 'Email',
                      value: _displayOrDash(item.email),
                    ),
                    _infoTile(
                      context,
                      icon: Icons.home_outlined,
                      label: 'Address',
                      value: _displayOrDash(item.customerDisplayAddress),
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip({required IconData icon, required String label}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            height: 28,
            width: 28,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildDistanceLabel() {
    final routeLabel = (item.routeDistanceLabel ?? '').toLowerCase();
    final routeReason = (item.routeDistanceReason ?? '').toLowerCase();
    if (routeLabel.contains('straight-line') ||
        routeReason.contains('straight-line')) {
      return 'Road route unavailable';
    }

    if (item.routeDistanceKm == null) {
      return 'Road route unavailable';
    }

    if (item.routeDistanceMeters != null && item.routeDistanceMeters! < 1000) {
      return 'Road route: ${item.routeDistanceMeters} m';
    }

    return 'Road route: ${item.routeDistanceKm!.toStringAsFixed(2)} km';
  }

  String _displayOrDash(String? value) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) {
      return '-';
    }

    return normalized;
  }

  String _formatJoinedDate(String? raw) {
    final normalized = (raw ?? '').trim();
    if (normalized.isEmpty) {
      return '-';
    }

    final date = DateTime.tryParse(normalized)?.toLocal();
    if (date == null) {
      return normalized;
    }

    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final month = months[date.month - 1];
    return '${date.day.toString().padLeft(2, '0')} $month ${date.year}';
  }
}
