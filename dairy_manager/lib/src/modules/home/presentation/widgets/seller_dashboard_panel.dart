import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../milk/milk_barrel.dart';

class SellerDashboardPanel extends StatefulWidget {
  const SellerDashboardPanel({super.key, required this.repository});

  final MilkRepository repository;

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
                    'Customers',
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
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    _SellerCustomerLegalInfoPage(item: item),
                              ),
                            );
                          },
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(item.customerName),
                          subtitle: Text(
                            '${item.customerDisplayAddress?.trim().isNotEmpty == true ? '${item.customerDisplayAddress}\n' : ''}$distanceLabel',
                          ),
                          isThreeLine:
                              item.customerDisplayAddress?.trim().isNotEmpty ==
                              true,
                          trailing: const Icon(Icons.chevron_right_rounded),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Information')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.customerName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _infoRow('Customer ID', item.customerId),
                  _infoRow(
                    'Joining Date',
                    _formatJoinedDate(item.organizationJoinedAt),
                  ),
                  _infoRow('Mobile', _displayOrDash(item.mobileNumber)),
                  _infoRow('Email', _displayOrDash(item.email)),
                  _infoRow(
                    'Address',
                    _displayOrDash(item.customerDisplayAddress),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
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
