import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../milk/data/repositories/milk_repository.dart';
import '../bloc/seller_workflow_cubit.dart';
import '../widgets/workflow_ui_widgets.dart';
import '../widgets/workflow_status_chip.dart';

class SellerDisputesAndCorrectionsPage extends StatefulWidget {
  const SellerDisputesAndCorrectionsPage({super.key, required this.repository});

  final MilkRepository repository;

  @override
  State<SellerDisputesAndCorrectionsPage> createState() =>
      _SellerDisputesAndCorrectionsPageState();
}

class _SellerDisputesAndCorrectionsPageState
    extends State<SellerDisputesAndCorrectionsPage> {
  final TextEditingController _correctionReasonController =
      TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1.0',
  );
  String _selectedDisputeStatusFilter = 'all';
  String _selectedCorrectionStatusFilter = 'all';

  @override
  void dispose() {
    _correctionReasonController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SellerWorkflowCubit(repository: widget.repository)..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Disputes & Corrections')),
        body: BlocConsumer<SellerWorkflowCubit, SellerWorkflowState>(
          listener: (context, state) {
            final error = state.errorMessage;
            if (error == null || error.trim().isEmpty) {
              return;
            }
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(error)));
          },
          builder: (context, state) {
            final cubit = context.read<SellerWorkflowCubit>();
            final disputes = _filteredDisputes(state.disputes);
            final correctionRequests = _filteredCorrections(
              state.correctionRequests,
            );
            final openDisputes = state.disputes
                .where(
                  (item) =>
                      (item['status']?.toString() ?? 'open').toLowerCase() ==
                      'open',
                )
                .length;
            final pendingCorrections = state.correctionRequests
                .where(
                  (item) =>
                      (item['status']?.toString() ?? 'pending').toLowerCase() ==
                      'pending',
                )
                .length;

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
                        label: 'Open disputes',
                        value: '$openDisputes',
                        icon: Icons.report_gmailerrorred_outlined,
                      ),
                      const SizedBox(width: 10),
                      WorkflowMetricCard(
                        label: 'Pending corrections',
                        value: '$pendingCorrections',
                        icon: Icons.pending_actions_rounded,
                      ),
                      const SizedBox(width: 10),
                      WorkflowMetricCard(
                        label: 'Logs loaded',
                        value: '${state.logs.length}',
                        icon: Icons.receipt_long_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create Correction Request',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pick a locked entry, choose the correct slot, and submit the new quantity you want recorded.',
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
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Ledger Log',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: state.logs
                                .map(
                                  (log) => DropdownMenuItem<String>(
                                    value: '${log['_id'] ?? ''}',
                                    child: Text(
                                      '${log['dateKey'] ?? '-'} • ${log['customerName'] ?? log['customerFirebaseUid'] ?? '-'}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                            selectedItemBuilder: (context) => state.logs
                                .map((log) {
                                  final label =
                                      '${log['dateKey'] ?? '-'} • ${log['customerName'] ?? log['customerFirebaseUid'] ?? '-'}';
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      child: Text(
                                        label,
                                        softWrap: false,
                                        maxLines: 1,
                                      ),
                                    ),
                                  );
                                })
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
                            initialValue: state.requestedSlot,
                            decoration: const InputDecoration(
                              labelText: 'Requested Slot',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'morning',
                                child: Text('Morning'),
                              ),
                              DropdownMenuItem(
                                value: 'evening',
                                child: Text('Evening'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              cubit.setRequestedSlot(value);
                            },
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _quantityController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Requested Quantity (L)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _correctionReasonController,
                            minLines: 3,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'Reason',
                              hintText:
                                  'Explain why this correction is needed.',
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
                                      final quantity =
                                          double.tryParse(
                                            _quantityController.text,
                                          ) ??
                                          0;
                                      await cubit.createCorrectionRequest(
                                        requestedQuantityLitres: quantity,
                                        reason:
                                            _correctionReasonController.text,
                                      );
                                      _correctionReasonController.clear();
                                    },
                              icon: const Icon(Icons.send_rounded),
                              label: const Text('Submit Correction Request'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionTitle(title: 'Open Disputes', count: disputes.length),
                  const SizedBox(height: 8),
                  WorkflowFilterChipBar(
                    selectedValue: _selectedDisputeStatusFilter,
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
                        _selectedDisputeStatusFilter = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  if (disputes.isEmpty)
                    const WorkflowEmptyState(
                      title: 'No disputes in this view',
                      message:
                          'There are no disputes matching the selected status. Open disputes can be resolved or rejected from here.',
                      icon: Icons.inbox_outlined,
                    )
                  else
                    ...disputes.map((item) {
                      final disputeId = item['_id']?.toString() ?? '';
                      final status = item['status']?.toString() ?? 'open';

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item['dateKey'] ?? '-'} • ${item['disputeType'] ?? 'other'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  WorkflowStatusChip(status: status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(item['message']?.toString() ?? ''),
                              if (status == 'open') ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: state.isSubmitting
                                            ? null
                                            : () => cubit.resolveDispute(
                                                disputeId: disputeId,
                                                approve: false,
                                              ),
                                        icon: const Icon(Icons.close_rounded),
                                        label: const Text('Reject'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: state.isSubmitting
                                            ? null
                                            : () => cubit.resolveDispute(
                                                disputeId: disputeId,
                                                approve: true,
                                              ),
                                        icon: const Icon(Icons.check_rounded),
                                        label: const Text('Resolve'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 14),
                  _SectionTitle(
                    title: 'Correction Requests',
                    count: correctionRequests.length,
                  ),
                  const SizedBox(height: 8),
                  WorkflowFilterChipBar(
                    selectedValue: _selectedCorrectionStatusFilter,
                    options: const [
                      WorkflowFilterOption(label: 'All', value: 'all'),
                      WorkflowFilterOption(label: 'Pending', value: 'pending'),
                      WorkflowFilterOption(
                        label: 'Approved',
                        value: 'approved',
                      ),
                      WorkflowFilterOption(
                        label: 'Rejected',
                        value: 'rejected',
                      ),
                    ],
                    onSelected: (value) {
                      setState(() {
                        _selectedCorrectionStatusFilter = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  if (correctionRequests.isEmpty)
                    const WorkflowEmptyState(
                      title: 'No correction requests in this view',
                      message:
                          'Submitted correction requests will appear here with their current review status.',
                      icon: Icons.inbox_outlined,
                    )
                  else
                    ...correctionRequests.map(
                      (item) => Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            '${item['dateKey'] ?? '-'} • ${item['requestedSlot'] ?? '-'}',
                          ),
                          subtitle: Text(
                            'Qty: ${item['requestedQuantityLitres'] ?? '-'}L\n${item['reason'] ?? '-'}',
                          ),
                          isThreeLine: true,
                          trailing: WorkflowStatusChip(
                            status: item['status']?.toString() ?? 'pending',
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

  List<Map<String, dynamic>> _filteredDisputes(
    List<Map<String, dynamic>> disputes,
  ) {
    if (_selectedDisputeStatusFilter == 'all') {
      return disputes;
    }

    return disputes
        .where(
          (item) =>
              (item['status']?.toString() ?? 'open').toLowerCase() ==
              _selectedDisputeStatusFilter,
        )
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _filteredCorrections(
    List<Map<String, dynamic>> requests,
  ) {
    if (_selectedCorrectionStatusFilter == 'all') {
      return requests;
    }

    return requests
        .where(
          (item) =>
              (item['status']?.toString() ?? 'pending').toLowerCase() ==
              _selectedCorrectionStatusFilter,
        )
        .toList(growable: false);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        Text(
          '$count item${count == 1 ? '' : 's'}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
