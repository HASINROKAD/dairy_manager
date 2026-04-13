import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constant/widgets/app_shared_widgets.dart';
import '../../data/repositories/home_repository.dart';
import '../bloc/customer_join_cubit.dart';
import '../../../milk/milk_barrel.dart';

class CustomerLedgerPanel extends StatefulWidget {
  const CustomerLedgerPanel({
    super.key,
    required this.repository,
    required this.homeRepository,
    required this.userLatitude,
    required this.userLongitude,
  });

  final MilkRepository repository;
  final HomeRepository homeRepository;
  final double? userLatitude;
  final double? userLongitude;

  @override
  State<CustomerLedgerPanel> createState() => _CustomerLedgerPanelState();
}

class _CustomerLedgerPanelState extends State<CustomerLedgerPanel> {
  late Future<List<LedgerEntry>> _futureLedger;
  late String _selectedMonthKey;
  late final CustomerJoinCubit _joinCubit;

  @override
  void initState() {
    super.initState();
    _futureLedger = widget.repository.fetchMyLedger();
    _selectedMonthKey = _monthKey(DateTime.now());
    _joinCubit = CustomerJoinCubit(repository: widget.homeRepository)
      ..load(latitude: widget.userLatitude, longitude: widget.userLongitude);
  }

  @override
  void dispose() {
    _joinCubit.close();
    super.dispose();
  }

  String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  String _monthLabel(String monthKey) {
    const monthNames = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final parts = monthKey.split('-');
    if (parts.length != 2) {
      return monthKey;
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);

    if (year == null || month == null || month < 1 || month > 12) {
      return monthKey;
    }

    return '${monthNames[month - 1]} $year';
  }

  int _daysInMonth(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length != 2) {
      return 31;
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);

    if (year == null || month == null || month < 1 || month > 12) {
      return 31;
    }

    return DateTime(year, month + 1, 0).day;
  }

  int? _extractDay(String dateKey) {
    final date = DateTime.tryParse(dateKey);
    if (date != null) {
      return date.day;
    }

    final split = dateKey.split('-');
    if (split.isNotEmpty) {
      return int.tryParse(split.last);
    }

    return null;
  }

  double _monthlyTotalRupees(List<LedgerEntry> logs, String monthKey) {
    final totalPaise = logs
        .where((log) => log.dateKey.startsWith(monthKey))
        .fold<int>(0, (sum, log) => sum + log.totalPricePaise);

    return totalPaise / 100;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _joinCubit,
      child: BlocConsumer<CustomerJoinCubit, CustomerJoinState>(
        listenWhen: (previous, current) =>
            previous.actionVersion != current.actionVersion,
        listener: (context, state) {
          final message = state.actionMessage ?? state.actionError;
          if (message == null || message.trim().isEmpty) {
            return;
          }

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
        builder: (context, state) {
          return FutureBuilder<List<LedgerEntry>>(
            future: _futureLedger,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                final errorText = AppFeedback.formatError(snapshot.error);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Could not load your ledger.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      errorText,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _futureLedger = widget.repository.fetchMyLedger();
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                );
              }

              final logs = snapshot.data ?? <LedgerEntry>[];
              final now = DateTime.now();
              final previousMonthDate = DateTime(now.year, now.month - 1, 1);
              final monthOptions = <String>[
                _monthKey(now),
                _monthKey(previousMonthDate),
              ];
              final selectedMonth = monthOptions.contains(_selectedMonthKey)
                  ? _selectedMonthKey
                  : monthOptions.first;

              final monthlyTotal = _monthlyTotalRupees(logs, selectedMonth);
              final selectedMonthLogs = logs
                  .where((entry) => entry.dateKey.startsWith(selectedMonth))
                  .toList(growable: false);

              final morningByDay = <int, double>{};
              for (final entry in selectedMonthLogs) {
                final day = _extractDay(entry.dateKey);
                if (day == null) {
                  continue;
                }
                morningByDay[day] =
                    (morningByDay[day] ?? 0) + entry.quantityLitres;
              }

              final dayCount = _daysInMonth(selectedMonth);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedMonth,
                          decoration: const InputDecoration(
                            labelText: 'Month',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: monthOptions
                              .map(
                                (monthKey) => DropdownMenuItem<String>(
                                  value: monthKey,
                                  child: Text(_monthLabel(monthKey)),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _selectedMonthKey = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(
                          'Total: ₹${monthlyTotal.toStringAsFixed(2)}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (selectedMonthLogs.isEmpty)
                    const Text(
                      'No milk card entries available for selected month.',
                    )
                  else
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.5),
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Table(
                        columnWidths: const <int, TableColumnWidth>{
                          0: FlexColumnWidth(1),
                          1: FlexColumnWidth(2),
                          2: FlexColumnWidth(2),
                        },
                        border: TableBorder.all(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                        children: [
                          const TableRow(
                            decoration: BoxDecoration(color: Color(0xFFEFF3F7)),
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(
                                  child: Text(
                                    'Date',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(
                                  child: Text(
                                    'Morning',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(
                                  child: Text(
                                    'Evening',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ...List<TableRow>.generate(dayCount, (index) {
                            final day = index + 1;
                            final morningQty = morningByDay[day];
                            final dayText = day.toString().padLeft(2, '0');

                            return TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Center(child: Text(dayText)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Center(
                                    child: Text(
                                      morningQty == null
                                          ? '-'
                                          : morningQty.toStringAsFixed(1),
                                    ),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6),
                                  child: Center(child: Text('-')),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nearby sellers (within 5 km)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  BlocBuilder<CustomerJoinCubit, CustomerJoinState>(
                    builder: (context, joinState) {
                      if (!joinState.hasLocation) {
                        return const Text(
                          'Set your location to discover nearby sellers.',
                        );
                      }

                      if (joinState.isLoadingNearby) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (joinState.nearbyError != null &&
                          joinState.nearbySellers.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Could not load nearby sellers.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () {
                                context.read<CustomerJoinCubit>().load(
                                  latitude: widget.userLatitude,
                                  longitude: widget.userLongitude,
                                );
                              },
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                            ),
                          ],
                        );
                      }

                      if (joinState.nearbySellers.isEmpty) {
                        return const Text(
                          'No nearby sellers found in 5 km range.',
                        );
                      }

                      final pendingBySellerId = <String>{
                        for (final request in joinState.joinRequests)
                          if (request.status == 'pending') request.sellerUserId,
                      };
                      final joinedBySellerId = <String>{
                        for (final request in joinState.joinRequests)
                          if (request.status == 'accepted')
                            request.sellerUserId,
                      };

                      return Column(
                        children: joinState.nearbySellers
                            .map((seller) {
                              final hasPendingRequest = pendingBySellerId
                                  .contains(seller.sellerUserId);
                              final isJoinedOrganization = joinedBySellerId
                                  .contains(seller.sellerUserId);
                              final isSubmitting =
                                  joinState.submittingSellerId ==
                                  seller.sellerUserId;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(seller.name),
                                  subtitle: Text(
                                    '${seller.displayAddress.isEmpty ? 'Address not available' : seller.displayAddress}\n${seller.distanceKm.toStringAsFixed(2)} km away',
                                  ),
                                  isThreeLine: true,
                                  trailing: FilledButton(
                                    style: isJoinedOrganization
                                        ? FilledButton.styleFrom(
                                            backgroundColor:
                                                Colors.grey.shade400,
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor:
                                                Colors.grey.shade400,
                                            disabledForegroundColor:
                                                Colors.white,
                                          )
                                        : null,
                                    onPressed:
                                        hasPendingRequest ||
                                            isSubmitting ||
                                            isJoinedOrganization
                                        ? null
                                        : () {
                                            context
                                                .read<CustomerJoinCubit>()
                                                .sendJoinRequest(
                                                  seller.sellerUserId,
                                                );
                                          },
                                    child: Text(
                                      isJoinedOrganization
                                          ? 'Joined'
                                          : hasPendingRequest
                                          ? 'Pending'
                                          : (isSubmitting
                                                ? 'Sending...'
                                                : 'Join'),
                                    ),
                                  ),
                                ),
                              );
                            })
                            .toList(growable: false),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'My join requests',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      BlocBuilder<CustomerJoinCubit, CustomerJoinState>(
                        builder: (context, joinState) {
                          return IconButton(
                            onPressed: joinState.isLoadingRequests
                                ? null
                                : () {
                                    context
                                        .read<CustomerJoinCubit>()
                                        .refreshJoinRequests();
                                  },
                            icon: const Icon(Icons.refresh_rounded),
                          );
                        },
                      ),
                    ],
                  ),
                  BlocBuilder<CustomerJoinCubit, CustomerJoinState>(
                    builder: (context, joinState) {
                      if (joinState.isLoadingRequests) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (joinState.requestError != null &&
                          joinState.joinRequests.isEmpty) {
                        return Text(
                          'Could not load join requests.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        );
                      }

                      if (joinState.joinRequests.isEmpty) {
                        return const Text('No join requests yet.');
                      }

                      return Column(
                        children: joinState.joinRequests
                            .map((request) {
                              final statusColor = switch (request.status) {
                                'accepted' => Colors.green,
                                'rejected' => Colors.red,
                                _ => Colors.orange,
                              };

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(request.sellerName ?? 'Seller'),
                                  subtitle:
                                      request.rejectionReason != null &&
                                          request.rejectionReason!
                                              .trim()
                                              .isNotEmpty
                                      ? Text(
                                          'Reason: ${request.rejectionReason}',
                                        )
                                      : null,
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      request.status.toUpperCase(),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            })
                            .toList(growable: false),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
