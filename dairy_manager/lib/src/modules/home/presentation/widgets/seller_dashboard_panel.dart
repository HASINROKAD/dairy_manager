import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../milk/milk_barrel.dart';

class SellerDashboardPanel extends StatelessWidget {
  const SellerDashboardPanel({super.key, required this.repository});

  final MilkRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          DeliveryBloc(repository: repository)..add(const LoadDailySheet()),
      child: BlocBuilder<DeliveryBloc, DeliveryState>(
        builder: (context, state) {
          if (state.status == DeliveryStatus.loading && state.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == DeliveryStatus.failure && state.items.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.errorMessage ?? 'Could not load daily sheet.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    context.read<DeliveryBloc>().add(const LoadDailySheet());
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
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Seller Dashboard',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed:
                        state.items.isEmpty ||
                            state.status == DeliveryStatus.submitting
                        ? null
                        : () {
                            context.read<DeliveryBloc>().add(
                              const ConfirmBulkDelivery(),
                            );
                          },
                    icon: const Icon(Icons.done_all_rounded),
                    label: Text(
                      state.status == DeliveryStatus.submitting
                          ? 'Marking...'
                          : 'Mark All Delivered',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...state.items.map(
                (item) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(item.customerName),
                    subtitle: Text(
                      'Qty: ${item.quantityLitres.toStringAsFixed(1)} L',
                    ),
                    leading: Icon(
                      item.delivered
                          ? Icons.check_circle
                          : Icons.local_shipping,
                      color: item.delivered ? Colors.green : Colors.blue,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            context.read<DeliveryBloc>().add(
                              DecrementQty(item.customerId),
                            );
                          },
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                        Text(item.quantityLitres.toStringAsFixed(1)),
                        IconButton(
                          onPressed: () {
                            context.read<DeliveryBloc>().add(
                              IncrementQty(item.customerId),
                            );
                          },
                          icon: const Icon(Icons.add_circle_outline_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
