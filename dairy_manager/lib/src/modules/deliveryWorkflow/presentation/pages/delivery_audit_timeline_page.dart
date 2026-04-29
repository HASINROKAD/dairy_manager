import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../milk/data/repositories/milk_repository.dart';
import '../bloc/audit_timeline_cubit.dart';
import '../widgets/workflow_ui_widgets.dart';

String _formatAuditDateTime(String? raw) {
  if ((raw ?? '').trim().isEmpty) {
    return '-';
  }

  final parsed = DateTime.tryParse(raw!);
  if (parsed == null) {
    return raw;
  }

  final local = parsed.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';

  return '${local.day.toString().padLeft(2, '0')} ${_monthName(local.month)} ${local.year}, $hour:$minute $suffix';
}

String _monthName(int month) {
  const names = <String>[
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

  if (month < 1 || month > 12) {
    return '-';
  }

  return names[month - 1];
}

class DeliveryAuditTimelinePage extends StatelessWidget {
  const DeliveryAuditTimelinePage({
    super.key,
    required this.repository,
    required this.isSeller,
  });

  final MilkRepository repository;
  final bool isSeller;

  @override
  Widget build(BuildContext context) {
    if (isSeller) {
      return _SellerAuditTimelineView(repository: repository);
    }

    return _CustomerAuditTimelineView(repository: repository);
  }
}

class _CustomerAuditTimelineView extends StatelessWidget {
  const _CustomerAuditTimelineView({required this.repository});

  final MilkRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          AuditTimelineCubit(repository: repository, isSeller: false)..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('My Audit Timeline')),
        body: BlocBuilder<AuditTimelineCubit, AuditTimelineState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if ((state.errorMessage ?? '').trim().isNotEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: context.read<AuditTimelineCubit>().load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state.entries.isEmpty) {
              return const Center(child: Text('No audit entries yet.'));
            }

            return RefreshIndicator(
              onRefresh: context.read<AuditTimelineCubit>().load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.entries.length,
                itemBuilder: (context, index) {
                  return _AuditEntryCard(item: state.entries[index]);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SellerAuditTimelineView extends StatefulWidget {
  const _SellerAuditTimelineView({required this.repository});

  final MilkRepository repository;

  @override
  State<_SellerAuditTimelineView> createState() =>
      _SellerAuditTimelineViewState();
}

class _SellerAuditTimelineViewState extends State<_SellerAuditTimelineView> {
  late Future<List<Map<String, dynamic>>> _customersFuture;
  List<Map<String, dynamic>> _customers = const [];

  @override
  void initState() {
    super.initState();
    _customersFuture = _loadCustomers();
  }

  Future<void> _reloadAll() async {
    setState(() {
      _customersFuture = _loadCustomers();
    });

    await _customersFuture;
  }

  Future<List<Map<String, dynamic>>> _loadCustomers() async {
    final customers = await widget.repository.fetchSellerCustomers();
    customers.sort(
      (left, right) => _parseLinkedAt(
        left['linkedAt'],
      ).compareTo(_parseLinkedAt(right['linkedAt'])),
    );

    if (!mounted) {
      return customers;
    }

    setState(() {
      _customers = customers;
    });

    return customers;
  }

  void _selectCustomer(Map<String, dynamic> customer) {
    final customerFirebaseUid = _customerFirebaseUid(customer);
    if (customerFirebaseUid.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SellerCustomerAuditTimelinePage(
          repository: widget.repository,
          customerFirebaseUid: customerFirebaseUid,
          customerName: _customerName(customer),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seller Audit Timeline')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _customersFuture,
        builder: (context, snapshot) {
          final isLoading =
              snapshot.connectionState == ConnectionState.waiting &&
              _customers.isEmpty;

          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if ((snapshot.hasError || snapshot.error != null) &&
              _customers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.error?.toString() ?? 'Unable to load customers.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _reloadAll,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final customers = snapshot.data ?? _customers;
          if (customers.isEmpty) {
            return const Center(
              child: Text('No customers are linked to this organization yet.'),
            );
          }

          return RefreshIndicator(
            onRefresh: _reloadAll,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Customers Linked To This Organization',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ...customers.map((customer) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).dividerColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        onTap: () => _selectCustomer(customer),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                          child: Text(
                            _customerInitial(customer),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text(
                          _customerName(customer),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  String _customerFirebaseUid(Map<String, dynamic> customer) {
    return customer['customerFirebaseUid']?.toString().trim() ?? '';
  }

  String _customerName(Map<String, dynamic> customer) {
    final name = customer['name']?.toString().trim() ?? '';
    return name.isEmpty ? 'Customer' : name;
  }

  String _customerInitial(Map<String, dynamic> customer) {
    final name = _customerName(customer).trim();
    if (name.isEmpty) {
      return 'C';
    }

    return name.substring(0, 1).toUpperCase();
  }

  DateTime _parseLinkedAt(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _SellerCustomerAuditTimelinePage extends StatefulWidget {
  const _SellerCustomerAuditTimelinePage({
    required this.repository,
    required this.customerFirebaseUid,
    required this.customerName,
  });

  final MilkRepository repository;
  final String customerFirebaseUid;
  final String customerName;

  @override
  State<_SellerCustomerAuditTimelinePage> createState() =>
      _SellerCustomerAuditTimelinePageState();
}

class _SellerCustomerAuditTimelinePageState
    extends State<_SellerCustomerAuditTimelinePage> {
  late Future<List<Map<String, dynamic>>> _entriesFuture;

  @override
  void initState() {
    super.initState();
    _entriesFuture = _loadEntries();
  }

  Future<List<Map<String, dynamic>>> _loadEntries() async {
    final payload = await widget.repository.fetchSellerDeliveryAudit(
      customerFirebaseUid: widget.customerFirebaseUid,
    );

    return (payload['entries'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Future<void> _reload() async {
    setState(() {
      _entriesFuture = _loadEntries();
    });
    await _entriesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.customerName} Audit Timeline')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: WorkflowEmptyState(
                  title: 'Unable to load audit timeline',
                  message:
                      snapshot.error?.toString() ??
                      'Something went wrong while loading this customer timeline.',
                  icon: Icons.error_outline_rounded,
                ),
              ),
            );
          }

          final entries = snapshot.data ?? const <Map<String, dynamic>>[];
          if (entries.isEmpty) {
            return const Center(
              child: WorkflowEmptyState(
                title: 'No audit entries yet',
                message:
                    'This customer does not have any audit events for the selected organization yet.',
                icon: Icons.inbox_outlined,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AuditEntryCard(item: entries[index]),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AuditEntryCard extends StatelessWidget {
  const _AuditEntryCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final action = item['action']?.toString() ?? 'unknown';
    final timestamp = item['createdAt']?.toString();
    final dateKey = item['dateKey']?.toString() ?? '-';
    final reason = item['reason']?.toString();
    final actorRole = _roleLabel(item['actorRole']?.toString());
    final changeLine = _buildChangeLine(item);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _actionLabel(action),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  child: Text(
                    actorRole,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _actionDescription(action),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text('Delivery Date: ${_formatDateKey(dateKey)}'),
            Text('Updated At: ${_formatAuditDateTime(timestamp)}'),
            if ((changeLine ?? '').isNotEmpty) Text(changeLine!),
            if (reason != null && reason.trim().isNotEmpty)
              Text('Reason: $reason'),
          ],
        ),
      ),
    );
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'log_created':
        return 'Entry Created';
      case 'log_slot_updated':
        return 'Slot Updated';
      case 'log_adjusted_same_day':
        return 'Same-Day Adjustment';
      case 'correction_requested':
        return 'Correction Requested';
      case 'correction_approved':
        return 'Correction Approved';
      case 'correction_rejected':
        return 'Correction Rejected';
      case 'dispute_opened':
        return 'Dispute Raised';
      case 'dispute_resolved':
        return 'Dispute Resolved';
      case 'dispute_rejected':
        return 'Dispute Rejected';
      default:
        return action.replaceAll('_', ' ').trim();
    }
  }

  String _actionDescription(String action) {
    switch (action) {
      case 'log_created':
        return 'A new milk log was added for this date.';
      case 'log_slot_updated':
        return 'Milk quantity for a delivery slot was updated.';
      case 'log_adjusted_same_day':
        return 'The same-day quantity was manually adjusted.';
      case 'correction_requested':
        return 'A correction request was submitted for this entry.';
      case 'correction_approved':
        return 'The correction request was approved.';
      case 'correction_rejected':
        return 'The correction request was rejected.';
      case 'dispute_opened':
        return 'A dispute was raised on this entry.';
      case 'dispute_resolved':
        return 'The dispute was resolved.';
      case 'dispute_rejected':
        return 'The dispute was rejected.';
      default:
        return 'Audit event recorded.';
    }
  }

  String _roleLabel(String? role) {
    switch ((role ?? '').trim().toLowerCase()) {
      case 'seller':
        return 'Seller';
      case 'customer':
        return 'Customer';
      case 'system':
        return 'System';
      default:
        return 'Unknown';
    }
  }

  String _formatDateKey(String dateKey) {
    final date = DateTime.tryParse(dateKey);
    if (date == null) {
      return dateKey;
    }

    return '${date.day.toString().padLeft(2, '0')} ${_monthName(date.month)} ${date.year}';
  }

  String? _buildChangeLine(Map<String, dynamic> item) {
    final before = item['before'];
    final after = item['after'];
    if (before is! Map || after is! Map) {
      return null;
    }

    final beforeMap = before.cast<String, dynamic>();
    final afterMap = after.cast<String, dynamic>();
    final beforeQty = _readQty(beforeMap);
    final afterQty = _readQty(afterMap);

    if ((beforeQty ?? '').isEmpty || (afterQty ?? '').isEmpty) {
      return null;
    }
    if (beforeQty == afterQty) {
      return null;
    }

    return 'Quantity: $beforeQty -> $afterQty';
  }

  String? _readQty(Map<String, dynamic> snapshot) {
    final morning = _asNum(snapshot['morningQuantityLitres']);
    final evening = _asNum(snapshot['eveningQuantityLitres']);
    if (morning != null || evening != null) {
      final m = (morning ?? 0).toStringAsFixed(1);
      final e = (evening ?? 0).toStringAsFixed(1);
      return '$m/$e L (day/night)';
    }

    final total = _asNum(snapshot['quantityLitres']);
    if (total != null) {
      return '${total.toStringAsFixed(1)} L';
    }

    return null;
  }

  double? _asNum(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    final text = value?.toString();
    if ((text ?? '').trim().isEmpty) {
      return null;
    }

    return double.tryParse(text!.trim());
  }
}
