import 'package:flutter/material.dart';

import '../../../milk/milk_barrel.dart';

class CustomerLedgerPanel extends StatefulWidget {
  const CustomerLedgerPanel({super.key, required this.repository});

  final MilkRepository repository;

  @override
  State<CustomerLedgerPanel> createState() => _CustomerLedgerPanelState();
}

class _CustomerLedgerPanelState extends State<CustomerLedgerPanel> {
  late Future<List<LedgerEntry>> _futureLedger;

  @override
  void initState() {
    super.initState();
    _futureLedger = widget.repository.fetchMyLedger();
  }

  double _monthlyTotalRupees(List<LedgerEntry> logs) {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final totalPaise = logs
        .where((log) => log.dateKey.startsWith(monthKey))
        .fold<int>(0, (sum, log) => sum + log.totalPricePaise);

    return totalPaise / 100;
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
          final errorText = snapshot.error.toString();
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
        final monthlyTotal = _monthlyTotalRupees(logs);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'My Ledger',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(
                  label: Text(
                    'This Month: ₹${monthlyTotal.toStringAsFixed(2)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              const Text('No delivery logs available yet.')
            else
              ...logs
                  .take(31)
                  .map(
                    (entry) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          entry.delivered ? Icons.check_circle : Icons.schedule,
                          color: entry.delivered ? Colors.green : Colors.orange,
                        ),
                        title: Text(entry.dateKey),
                        subtitle: Text(
                          '${entry.quantityLitres.toStringAsFixed(1)} L',
                        ),
                        trailing: Text(
                          '₹${entry.totalPriceRupees.toStringAsFixed(2)}',
                        ),
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }
}
