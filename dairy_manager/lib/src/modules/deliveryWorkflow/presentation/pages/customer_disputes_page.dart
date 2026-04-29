import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../milk/data/models/ledger_entry.dart';
import '../../../milk/data/repositories/milk_repository.dart';
import '../bloc/customer_dispute_cubit.dart';
import '../widgets/workflow_ui_widgets.dart';
import '../widgets/workflow_status_chip.dart';

class CustomerDisputesPage extends StatefulWidget {
  const CustomerDisputesPage({super.key, required this.repository});

  final MilkRepository repository;

  @override
  State<CustomerDisputesPage> createState() => _CustomerDisputesPageState();
}

class _CustomerDisputesPageState extends State<CustomerDisputesPage> {
  final TextEditingController _messageController = TextEditingController();
  String _selectedStatusFilter = 'all';

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          CustomerDisputeCubit(repository: widget.repository)..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('My Delivery Disputes')),
        body: BlocConsumer<CustomerDisputeCubit, CustomerDisputeState>(
          listener: (context, state) {
            final message = state.errorMessage;
            if (message == null || message.trim().isEmpty) {
              return;
            }

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          },
          builder: (context, state) {
            final cubit = context.read<CustomerDisputeCubit>();
            final disputes = _filteredDisputes(state.disputes);
            final openCount = state.disputes
                .where(
                  (item) =>
                      (item['status']?.toString() ?? 'open').toLowerCase() ==
                      'open',
                )
                .length;
            final closedCount = state.disputes.length - openCount;

            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return RefreshIndicator(
              onRefresh: cubit.load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      WorkflowMetricCard(
                        label: 'Total',
                        value: '${state.disputes.length}',
                        icon: Icons.list_alt_rounded,
                      ),
                      const SizedBox(width: 10),
                      WorkflowMetricCard(
                        label: 'Open',
                        value: '$openCount',
                        icon: Icons.hourglass_top_rounded,
                      ),
                      const SizedBox(width: 10),
                      WorkflowMetricCard(
                        label: 'Closed',
                        value: '$closedCount',
                        icon: Icons.verified_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Filter by status',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  WorkflowFilterChipBar(
                    selectedValue: _selectedStatusFilter,
                    options: const [
                      WorkflowFilterOption(label: 'All', value: 'all'),
                      WorkflowFilterOption(label: 'Open', value: 'open'),
                      WorkflowFilterOption(
                        label: 'Resolved',
                        value: 'resolved',
                      ),
                      WorkflowFilterOption(
                        label: 'Rejected',
                        value: 'rejected',
                      ),
                    ],
                    onSelected: (value) {
                      setState(() {
                        _selectedStatusFilter = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Raise New Dispute',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Choose the ledger entry, classify the issue, and add a concise explanation.',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: state.selectedLogId.isNotEmpty
                                ? state.selectedLogId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Select Ledger Entry',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: state.logs
                                .map(
                                  (entry) => DropdownMenuItem<String>(
                                    value: entry.id,
                                    child: Text(_entryLabel(entry)),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              cubit.setSelectedLogId(value);
                            },
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: state.disputeType,
                            decoration: const InputDecoration(
                              labelText: 'Dispute Type',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'wrong_quantity',
                                child: Text('Wrong Quantity'),
                              ),
                              DropdownMenuItem(
                                value: 'wrong_slot',
                                child: Text('Wrong Slot'),
                              ),
                              DropdownMenuItem(
                                value: 'not_delivered',
                                child: Text('Not Delivered'),
                              ),
                              DropdownMenuItem(
                                value: 'other',
                                child: Text('Other'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              cubit.setDisputeType(value);
                            },
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _messageController,
                            minLines: 3,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'Dispute Details',
                              hintText:
                                  'Describe what is incorrect and why you are raising the dispute.',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: state.isSubmitting
                                  ? null
                                  : () async {
                                      await cubit.submitDispute(
                                        message: _messageController.text,
                                      );
                                      _messageController.clear();
                                    },
                              icon: state.isSubmitting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded),
                              label: const Text('Submit Dispute'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Dispute Status',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${disputes.length} item${disputes.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (disputes.isEmpty)
                    const WorkflowEmptyState(
                      title: 'No disputes in this view',
                      message:
                          'There are no disputes matching the current filter. Submitted disputes will appear here with their latest status.',
                      icon: Icons.inbox_outlined,
                    )
                  else
                    ...disputes.map(
                      (item) => Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            (item['disputeType']?.toString() ?? 'other')
                                .replaceAll('_', ' '),
                          ),
                          subtitle: Text(
                            '${item['dateKey'] ?? '-'}\n${item['message'] ?? ''}',
                          ),
                          isThreeLine: true,
                          trailing: WorkflowStatusChip(
                            status: item['status']?.toString() ?? 'open',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _entryLabel(LedgerEntry entry) {
    final total = entry.quantityLitres.toStringAsFixed(1);
    return '${entry.dateKey} • ${entry.deliverySlot} • ${total}L';
  }

  List<Map<String, dynamic>> _filteredDisputes(
    List<Map<String, dynamic>> disputes,
  ) {
    if (_selectedStatusFilter == 'all') {
      return disputes;
    }

    return disputes
        .where(
          (item) =>
              (item['status']?.toString() ?? 'open').toLowerCase() ==
              _selectedStatusFilter,
        )
        .toList(growable: false);
  }
}
