import 'package:flutter/material.dart';

import '../../../../../core/constant/widgets/app_shared_widgets.dart';
import '../../../milk/milk_barrel.dart';

class CustomerLedgerPanel extends StatefulWidget {
  const CustomerLedgerPanel({
    super.key,
    required this.repository,
    required this.userLatitude,
    required this.userLongitude,
    required this.onOpenFeature,
  });

  final MilkRepository repository;
  final double? userLatitude;
  final double? userLongitude;
  final Future<void> Function(String featureKey) onOpenFeature;

  @override
  State<CustomerLedgerPanel> createState() => _CustomerLedgerPanelState();
}

class _CustomerLedgerPanelState extends State<CustomerLedgerPanel> {
  late Future<List<LedgerEntry>> _futureLedger;
  late String _selectedMonthKey;
  Map<String, dynamic> _monthlySummary = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _futureLedger = widget.repository.fetchMyLedger();
    _selectedMonthKey = _monthKey(DateTime.now());
    _loadMonthlySummary();
  }

  @override
  void dispose() {
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
    try {
      final summary = await widget.repository.fetchMyMonthlySummary(
        month: _selectedMonthKey,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _monthlySummary = summary;
      });
    } catch (error) {
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
    final totalPaise = logs
        .where((log) => log.dateKey.startsWith(monthKey))
        .fold<int>(0, (sum, log) => sum + log.totalPricePaise);

    return totalPaise / 100;
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
          morningByDay[day] = (morningByDay[day] ?? 0) + entry.quantityLitres;
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
                      _loadMonthlySummary();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Chip(label: Text('Total: ₹${monthlyTotal.toStringAsFixed(2)}')),
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
                      'Monthly summary (${_monthlySummary['month'] ?? selectedMonth})',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Delivered days: ${_monthlySummary['summary']?['deliveredDays'] ?? 0} • Adjusted: ${_monthlySummary['summary']?['adjustedDays'] ?? 0}',
                    ),
                    Text(
                      'Pending dues: ₹${((((_monthlySummary['summary']?['pendingPaise'] as num?) ?? 0) / 100)).toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (selectedMonthLogs.isEmpty)
              const Text('No milk card entries available for selected month.')
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
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: Text(
                              'Morning',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: Text(
                              'Evening',
                              style: TextStyle(fontWeight: FontWeight.w700),
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
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Center(child: Text(dayText)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
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
              'More Dairy Features',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _featureCard(
              icon: Icons.storefront_outlined,
              title: 'Nearby Sellers & Join Requests',
              subtitle: 'Find nearby sellers and track all join requests.',
              featureKey: 'customer_join',
            ),
            _featureCard(
              icon: Icons.report_problem_outlined,
              title: 'Delivery Issues',
              subtitle: 'Report issues and follow their latest status.',
              featureKey: 'customer_issues',
            ),
            _featureCard(
              icon: Icons.pause_circle_outline,
              title: 'Pause / Resume Delivery',
              subtitle: 'Schedule pause windows and resume active pauses.',
              featureKey: 'customer_pauses',
            ),
            _featureCard(
              icon: Icons.receipt_long_outlined,
              title: 'Billing Summary',
              subtitle: 'View monthly totals, dues, and billing trends.',
              featureKey: 'customer_billing',
            ),
          ],
        );
      },
    );
  }
}
