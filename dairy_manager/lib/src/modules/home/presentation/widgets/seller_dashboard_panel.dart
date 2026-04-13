import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/home_repository.dart';
import '../bloc/seller_join_requests_cubit.dart';
import '../../../milk/milk_barrel.dart';

class SellerDashboardPanel extends StatefulWidget {
  const SellerDashboardPanel({
    super.key,
    required this.repository,
    required this.homeRepository,
  });

  final MilkRepository repository;
  final HomeRepository homeRepository;

  @override
  State<SellerDashboardPanel> createState() => _SellerDashboardPanelState();
}

class _SellerDashboardPanelState extends State<SellerDashboardPanel> {
  late final DeliveryBloc _deliveryBloc;
  late final SellerJoinRequestsCubit _joinRequestsCubit;

  @override
  void initState() {
    super.initState();
    _deliveryBloc = DeliveryBloc(repository: widget.repository)
      ..add(const LoadDailySheet());
    _joinRequestsCubit = SellerJoinRequestsCubit(
      repository: widget.homeRepository,
    )..loadPending();
  }

  @override
  void dispose() {
    _deliveryBloc.close();
    _joinRequestsCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DeliveryBloc>.value(value: _deliveryBloc),
        BlocProvider<SellerJoinRequestsCubit>.value(value: _joinRequestsCubit),
      ],
      child: BlocListener<SellerJoinRequestsCubit, SellerJoinRequestsState>(
        listenWhen: (previous, current) =>
            previous.actionVersion != current.actionVersion,
        listener: (context, state) {
          final message = state.actionMessage ?? state.actionError;
          if (message == null || message.trim().isEmpty) {
            return;
          }

          // Refresh delivery routes immediately after request actions.
          context.read<DeliveryBloc>().add(const LoadDailySheet());

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
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

                        final distanceLabel = item.routeDistanceKm == null
                            ? '${item.routeDistanceLabel ?? 'Distance unavailable'}${(item.routeDistanceReason ?? '').trim().isEmpty ? '' : ' (${item.routeDistanceReason})'}'
                            : item.routeDistanceMeters != null &&
                                  item.routeDistanceMeters! < 1000
                            ? '${item.routeDistanceMeters} m away (${item.routeDistanceLabel ?? 'Nearby'})'
                            : '${item.routeDistanceKm!.toStringAsFixed(2)} km away (${item.routeDistanceLabel ?? 'Route'})';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(child: Text('${index + 1}')),
                            title: Text(item.customerName),
                            subtitle: Text(
                              '${item.customerDisplayAddress?.trim().isNotEmpty == true ? '${item.customerDisplayAddress}\n' : ''}$distanceLabel',
                            ),
                            isThreeLine:
                                item.customerDisplayAddress
                                    ?.trim()
                                    .isNotEmpty ==
                                true,
                            trailing: Icon(
                              item.delivered
                                  ? Icons.check_circle
                                  : Icons.route_outlined,
                              color: item.delivered
                                  ? Colors.green
                                  : Colors.blue,
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pending Join Requests',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                BlocBuilder<SellerJoinRequestsCubit, SellerJoinRequestsState>(
                  builder: (context, state) {
                    return IconButton(
                      onPressed: state.isLoading
                          ? null
                          : () {
                              context
                                  .read<SellerJoinRequestsCubit>()
                                  .loadPending();
                            },
                      icon: const Icon(Icons.refresh_rounded),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            BlocBuilder<SellerJoinRequestsCubit, SellerJoinRequestsState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.errorMessage != null && state.requests.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Could not load pending requests.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          context.read<SellerJoinRequestsCubit>().loadPending();
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  );
                }

                if (state.requests.isEmpty) {
                  return const Text('No pending requests.');
                }

                return Column(
                  children: state.requests
                      .map((request) {
                        final isActing = state.actingRequestId == request.id;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(request.customerName ?? 'Customer'),
                            subtitle: const Text(
                              'Wants to join your organization',
                            ),
                            trailing: Wrap(
                              spacing: 6,
                              children: [
                                OutlinedButton(
                                  onPressed: isActing
                                      ? null
                                      : () {
                                          context
                                              .read<SellerJoinRequestsCubit>()
                                              .review(
                                                requestId: request.id,
                                                action: 'reject',
                                              );
                                        },
                                  child: const Text('Reject'),
                                ),
                                FilledButton(
                                  onPressed: isActing
                                      ? null
                                      : () {
                                          context
                                              .read<SellerJoinRequestsCubit>()
                                              .review(
                                                requestId: request.id,
                                                action: 'accept',
                                              );
                                        },
                                  child: Text(
                                    isActing ? 'Please wait...' : 'Accept',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
