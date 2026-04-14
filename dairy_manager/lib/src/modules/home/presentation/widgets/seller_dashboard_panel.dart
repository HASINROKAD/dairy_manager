import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constant/constant_barrel.dart';
import '../../../milk/milk_barrel.dart';

class SellerDashboardPanel extends StatefulWidget {
  const SellerDashboardPanel({
    super.key,
    required this.repository,
    required this.onOpenFeature,
  });

  final MilkRepository repository;
  final Future<void> Function(String featureKey) onOpenFeature;

  @override
  State<SellerDashboardPanel> createState() => _SellerDashboardPanelState();
}

class _SellerDashboardPanelState extends State<SellerDashboardPanel> {
  late final DeliveryBloc _deliveryBloc;

  @override
  void initState() {
    super.initState();
    _deliveryBloc = DeliveryBloc(repository: widget.repository)
      ..add(const LoadDailySheet());
  }

  @override
  void dispose() {
    _deliveryBloc.close();
    super.dispose();
  }

  Widget _featureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String featureKey,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => widget.onOpenFeature(featureKey),
      ),
    );
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
                  const Text(
                    'Delivery Routes',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (state.items.isEmpty)
                    const Text(
                      'No assigned customers found for route planning.',
                    )
                  else
                    ...state.items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final reasonSuffix =
                          (item.routeDistanceReason ?? '').trim().isEmpty
                          ? ''
                          : ' (${item.routeDistanceReason})';

                      final distanceLabel = item.routeDistanceKm == null
                          ? '${item.routeDistanceLabel ?? 'Distance unavailable'}$reasonSuffix'
                          : item.routeDistanceMeters != null &&
                                item.routeDistanceMeters! < 1000
                          ? '${item.routeDistanceMeters} m away (${item.routeDistanceLabel ?? 'Nearby'})$reasonSuffix'
                          : '${item.routeDistanceKm!.toStringAsFixed(2)} km away (${item.routeDistanceLabel ?? 'Route'})$reasonSuffix';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(item.customerName),
                          subtitle: Text(
                            '${item.customerDisplayAddress?.trim().isNotEmpty == true ? '${item.customerDisplayAddress}\n' : ''}$distanceLabel',
                          ),
                          isThreeLine:
                              item.customerDisplayAddress?.trim().isNotEmpty ==
                              true,
                          trailing: item.delivered
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                )
                              : null,
                        ),
                      );
                    }),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'More Dairy Features',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _featureCard(
            icon: Icons.group_add_rounded,
            title: 'Pending Join Requests',
            subtitle: 'Review customer requests with filters and sorting.',
            featureKey: 'seller_requests',
          ),
          _featureCard(
            icon: Icons.tune_rounded,
            title: 'Capacity Controls',
            subtitle: 'Set safe limits for active customers and litres/day.',
            featureKey: 'seller_capacity',
          ),
          _featureCard(
            icon: Icons.report_problem_outlined,
            title: 'Delivery Issues',
            subtitle: 'Track complaints and mark them resolved.',
            featureKey: 'seller_issues',
          ),
          _featureCard(
            icon: Icons.pause_circle_outline,
            title: 'Delivery Pauses',
            subtitle: 'Review pause windows and resume active pauses.',
            featureKey: 'seller_pauses',
          ),
          _featureCard(
            icon: Icons.receipt_long_outlined,
            title: 'Billing Summary',
            subtitle: 'View monthly totals, dues, and customer breakdowns.',
            featureKey: 'seller_billing',
          ),
        ],
      ),
    );
  }
}
