import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constant/widgets/app_shared_widgets.dart';
import '../bloc/customer_ledger_ui_cubit.dart';
import '../../../milk/milk_barrel.dart';

class CustomerLedgerPanel extends StatefulWidget {
  const CustomerLedgerPanel({
    super.key,
    required this.repository,
    this.customerName,
    required this.userLatitude,
    required this.userLongitude,
  });

  final MilkRepository repository;
  final String? customerName;
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
              final selectedMonth = uiState.selectedMonthKey.trim().isEmpty
                  ? _monthKey(DateTime.now())
                  : uiState.selectedMonthKey;
              final summaryMonthKey =
                  (uiState.monthlySummary['month']
                          ?.toString()
                          .trim()
                          .isNotEmpty ??
                      false)
                  ? uiState.monthlySummary['month'].toString().trim()
                  : selectedMonth;
              final summaryMonthLabel = _formatMonthLabel(summaryMonthKey);
              final selectedMonthLogs = logs
                  .where((entry) => entry.dateKey.startsWith(selectedMonth))
                  .toList(growable: false);
              final displayName = (widget.customerName ?? '').trim().isEmpty
                  ? 'Customer'
                  : widget.customerName!.trim();
              final milkRate = selectedMonthLogs.isNotEmpty
                  ? selectedMonthLogs.first.basePricePerLitreRupees
                  : 0.0;

              final morningByDay = <int, double>{};
              final eveningByDay = <int, double>{};
              for (final entry in selectedMonthLogs) {
                final day = _extractDay(entry.dateKey);
                if (day == null) {
                  continue;
                }
                morningByDay[day] =
                    (morningByDay[day] ?? 0) + entry.morningQuantityLitres;
                eveningByDay[day] =
                    (eveningByDay[day] ?? 0) + entry.eveningQuantityLitres;
              }

              final dayCount = _daysInMonth(selectedMonth);
              const firstSectionLastDay = 16;
              const secondSectionStartDay = 17;
              const rowCount = 16;

              final firstSectionEndDay = dayCount < firstSectionLastDay
                  ? dayCount
                  : firstSectionLastDay;
              final secondSectionEndDay = dayCount < 31 ? dayCount : 31;

              var firstSectionDayTotal = 0.0;
              var firstSectionNightTotal = 0.0;
              for (var day = 1; day <= firstSectionEndDay; day++) {
                firstSectionDayTotal += morningByDay[day] ?? 0;
                firstSectionNightTotal += eveningByDay[day] ?? 0;
              }

              var secondSectionDayTotal = 0.0;
              var secondSectionNightTotal = 0.0;
              if (secondSectionEndDay >= secondSectionStartDay) {
                for (
                  var day = secondSectionStartDay;
                  day <= secondSectionEndDay;
                  day++
                ) {
                  secondSectionDayTotal += morningByDay[day] ?? 0;
                  secondSectionNightTotal += eveningByDay[day] ?? 0;
                }
              }

              final totalMilkLitres =
                  firstSectionDayTotal +
                  firstSectionNightTotal +
                  secondSectionDayTotal +
                  secondSectionNightTotal;
              final totalAmountFromLogs = selectedMonthLogs.fold<double>(
                0,
                (sum, entry) => sum + entry.totalPriceRupees,
              );
              final totalAmountPayable = totalAmountFromLogs > 0
                  ? totalAmountFromLogs
                  : (totalMilkLitres * milkRate);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _headerLine(
                            context: context,
                            label: 'Name',
                            value: displayName,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: _headerLine(
                                  context: context,
                                  label: 'Month',
                                  value: summaryMonthLabel,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _headerLine(
                                  context: context,
                                  label: 'Milk Rate',
                                  value: milkRate > 0
                                      ? 'Rs ${milkRate.toStringAsFixed(2)} / L'
                                      : '-',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Table(
                            columnWidths: const <int, TableColumnWidth>{
                              0: FlexColumnWidth(1),
                              1: FlexColumnWidth(1),
                              2: FlexColumnWidth(1),
                              3: FlexColumnWidth(1),
                              4: FlexColumnWidth(1),
                              5: FlexColumnWidth(1),
                            },
                            border: TableBorder.all(
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.35),
                              width: 0.8,
                            ),
                            children: [
                              TableRow(
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEFF3F7),
                                ),
                                children: [
                                  Container(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.09),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Date',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 5),
                                    child: Center(
                                      child: Text(
                                        'Day',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 5),
                                    child: Center(
                                      child: Text(
                                        'Night',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.09),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Date',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 5),
                                    child: Center(
                                      child: Text(
                                        'Day',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 5),
                                    child: Center(
                                      child: Text(
                                        'Night',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              ...List<TableRow>.generate(rowCount, (index) {
                                final firstDay = index + 1;
                                final secondDay = index + secondSectionStartDay;

                                final firstMorningQty = firstDay <= dayCount
                                    ? morningByDay[firstDay]
                                    : null;
                                final firstEveningQty = firstDay <= dayCount
                                    ? eveningByDay[firstDay]
                                    : null;
                                final secondMorningQty = secondDay <= dayCount
                                    ? morningByDay[secondDay]
                                    : null;
                                final secondEveningQty = secondDay <= dayCount
                                    ? eveningByDay[secondDay]
                                    : null;

                                final firstDayText = firstDay <= dayCount
                                    ? firstDay.toString().padLeft(2, '0')
                                    : '-';
                                final secondDayText = secondDay <= dayCount
                                    ? secondDay.toString().padLeft(2, '0')
                                    : '-';

                                return TableRow(
                                  children: [
                                    Container(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.06),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Center(child: Text(firstDayText)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Center(
                                        child: Text(
                                          firstMorningQty == null ||
                                                  firstMorningQty == 0
                                              ? '-'
                                              : firstMorningQty.toStringAsFixed(
                                                  1,
                                                ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Center(
                                        child: Text(
                                          firstEveningQty == null ||
                                                  firstEveningQty == 0
                                              ? '-'
                                              : firstEveningQty.toStringAsFixed(
                                                  1,
                                                ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.06),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Center(child: Text(secondDayText)),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Center(
                                        child: Text(
                                          secondMorningQty == null ||
                                                  secondMorningQty == 0
                                              ? '-'
                                              : secondMorningQty
                                                    .toStringAsFixed(1),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: Center(
                                        child: Text(
                                          secondEveningQty == null ||
                                                  secondEveningQty == 0
                                              ? '-'
                                              : secondEveningQty
                                                    .toStringAsFixed(1),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                              TableRow(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerLow,
                                ),
                                children: [
                                  Container(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.09),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Total',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${firstSectionDayTotal.toStringAsFixed(1)} L',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${firstSectionNightTotal.toStringAsFixed(1)} L',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.09),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Total',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${secondSectionDayTotal.toStringAsFixed(1)} L',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 5,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${secondSectionNightTotal.toStringAsFixed(1)} L',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).dividerColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Milk: ${totalMilkLitres.toStringAsFixed(1)} L',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Total Amount Payable: Rs ${totalAmountPayable.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  String _formatMonthLabel(String monthKey) {
    final normalized = monthKey.trim();
    final parts = normalized.split('-');
    if (parts.length < 2) {
      return normalized;
    }

    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) {
      return normalized;
    }

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

    return monthNames[month - 1];
  }

  Widget _headerLine({
    required BuildContext context,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
