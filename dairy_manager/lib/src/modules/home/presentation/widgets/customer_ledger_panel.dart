import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constant/widgets/app_shared_widgets.dart';
import '../bloc/customer_ledger_ui_cubit.dart';
import '../../../milk/milk_barrel.dart';

class CustomerLedgerPanel extends StatefulWidget {
  const CustomerLedgerPanel({
    super.key,
    required this.repository,
    required this.userLatitude,
    required this.userLongitude,
  });

  final MilkRepository repository;
  final double? userLatitude;
  final double? userLongitude;

  @override
  State<CustomerLedgerPanel> createState() => _CustomerLedgerPanelState();
}

class _CustomerLedgerPanelState extends State<CustomerLedgerPanel> {
  late final CustomerLedgerUiCubit _uiCubit;

  @override
  void initState() {
    super.initState();
    final initialMonthKey = _monthKey(DateTime.now());
    _uiCubit = CustomerLedgerUiCubit(
      initialLedgerFuture: widget.repository.fetchMyLedger(),
      initialMonthKey: initialMonthKey,
    );
    _loadMonthlySummary();
  }

  @override
  void dispose() {
    _uiCubit.close();
    super.dispose();
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _loadMonthlySummary() async {
    _uiCubit.setSummaryLoading(true);
    try {
      final summary = await widget.repository.fetchMyMonthlySummary(
        month: _uiCubit.state.selectedMonthKey,
      );
      if (!mounted) {
        return;
      }
      _uiCubit.setMonthlySummary(summary);
    } catch (error) {
      _uiCubit.setSummaryError(AppFeedback.formatError(error));
      _showMessage(error.toString(), error: true);
    }
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
    final totalRupees = logs
        .where((log) => log.dateKey.startsWith(monthKey))
        .fold<double>(0, (sum, log) => sum + log.totalPriceRupees);

    return totalRupees;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _uiCubit,
      child: BlocBuilder<CustomerLedgerUiCubit, CustomerLedgerUiState>(
        builder: (context, uiState) {
          return FutureBuilder<List<LedgerEntry>>(
            future: uiState.ledgerFuture,
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
                        _uiCubit.retryLedger(widget.repository.fetchMyLedger());
                        _loadMonthlySummary();
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
              final selectedMonth =
                  monthOptions.contains(uiState.selectedMonthKey)
                  ? uiState.selectedMonthKey
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

                            _uiCubit.setSelectedMonthKey(value);
                            _loadMonthlySummary();
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
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly summary (${uiState.monthlySummary['month'] ?? selectedMonth})',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Delivered days: ${uiState.monthlySummary['summary']?['deliveredDays'] ?? 0} • Adjusted: ${uiState.monthlySummary['summary']?['adjustedDays'] ?? 0}',
                          ),
                          Text(
                            'Pending dues: ₹${(((uiState.monthlySummary['summary']?['pendingRupees'] as num?) ?? 0)).toStringAsFixed(2)}',
                          ),
                          if (uiState.isSummaryLoading)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                        ],
                      ),
                    ),
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
                ],
              );
            },
          );
        },
      ),
    );
  }
}
