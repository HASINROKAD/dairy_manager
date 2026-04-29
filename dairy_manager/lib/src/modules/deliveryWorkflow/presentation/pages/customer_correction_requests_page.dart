import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../milk/data/repositories/milk_repository.dart';
import '../bloc/customer_corrections_cubit.dart';
import '../widgets/workflow_ui_widgets.dart';
import '../widgets/workflow_status_chip.dart';

class CustomerCorrectionRequestsPage extends StatefulWidget {
  const CustomerCorrectionRequestsPage({super.key, required this.repository});

  final MilkRepository repository;

  @override
  State<CustomerCorrectionRequestsPage> createState() =>
      _CustomerCorrectionRequestsPageState();
}

class _CustomerCorrectionRequestsPageState
    extends State<CustomerCorrectionRequestsPage> {
  String _selectedStatusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          CustomerCorrectionsCubit(repository: widget.repository)..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Correction Requests')),
        body: BlocConsumer<CustomerCorrectionsCubit, CustomerCorrectionsState>(
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
            final cubit = context.read<CustomerCorrectionsCubit>();
            final requests = _filteredRequests(state.requests);
            final pendingCount = state.requests
                .where(
                  (item) =>
                      (item['status']?.toString() ?? 'pending').toLowerCase() ==
                      'pending',
                )
                .length;
            final reviewedCount = state.requests.length - pendingCount;

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
                        value: '${state.requests.length}',
                        icon: Icons.list_alt_rounded,
                      ),
                      const SizedBox(width: 10),
                      WorkflowMetricCard(
                        label: 'Pending',
                        value: '$pendingCount',
                        icon: Icons.hourglass_top_rounded,
                      ),
                      const SizedBox(width: 10),
                      WorkflowMetricCard(
                        label: 'Reviewed',
                        value: '$reviewedCount',
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
                        _selectedStatusFilter = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pending and past correction requests from seller.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (requests.isEmpty)
                    const WorkflowEmptyState(
                      title: 'No correction requests in this view',
                      message:
                          'Seller corrections matching the current filter will appear here. Pending items can be approved or rejected.',
                      icon: Icons.inbox_outlined,
                    )
                  else
                    ...requests.map((item) {
                      final status = item['status']?.toString() ?? 'pending';
                      final requestId = item['_id']?.toString() ?? '';

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
                                      'Date: ${item['dateKey'] ?? '-'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  WorkflowStatusChip(status: status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Requested: ${item['requestedSlot'] ?? '-'} • ${item['requestedQuantityLitres'] ?? '-'}L',
                              ),
                              const SizedBox(height: 4),
                              Text('Reason: ${item['reason'] ?? '-'}'),
                              if (status == 'pending') ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: state.isSubmitting
                                            ? null
                                            : () => cubit.reject(
                                                requestId: requestId,
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
                                            : () => cubit.approve(
                                                requestId: requestId,
                                              ),
                                        icon: const Icon(Icons.check_rounded),
                                        label: const Text('Approve'),
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filteredRequests(
    List<Map<String, dynamic>> requests,
  ) {
    if (_selectedStatusFilter == 'all') {
      return requests;
    }

    return requests
        .where(
          (item) =>
              (item['status']?.toString() ?? 'pending').toLowerCase() ==
              _selectedStatusFilter,
        )
        .toList(growable: false);
  }
}
