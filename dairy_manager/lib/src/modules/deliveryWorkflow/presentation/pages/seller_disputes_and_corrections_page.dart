import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../milk/data/repositories/milk_repository.dart';
import '../bloc/seller_workflow_cubit.dart';
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

            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return RefreshIndicator(
              onRefresh: cubit.load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create Correction Request',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
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
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Reason',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
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
                                      reason: _correctionReasonController.text,
                                    );
                                    _correctionReasonController.clear();
                                  },
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('Submit Correction Request'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Open Disputes',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (state.disputes.isEmpty)
                    const Text('No disputes found.')
                  else
                    ...state.disputes.map((item) {
                      final disputeId = item['_id']?.toString() ?? '';
                      final status = item['status']?.toString() ?? 'open';

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
                  const Text(
                    'Correction Requests',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (state.correctionRequests.isEmpty)
                    const Text('No correction requests raised yet.')
                  else
                    ...state.correctionRequests.map(
                      (item) => Card(
                        child: ListTile(
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
}
