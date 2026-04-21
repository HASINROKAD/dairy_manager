import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../milk/data/repositories/milk_repository.dart';
import '../bloc/customer_corrections_cubit.dart';
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

            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return RefreshIndicator(
              onRefresh: cubit.load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Pending and past correction requests from seller.',
                  ),
                  const SizedBox(height: 12),
                  if (state.requests.isEmpty)
                    const Text('No correction requests found.')
                  else
                    ...state.requests.map((item) {
                      final status = item['status']?.toString() ?? 'pending';
                      final requestId = item['_id']?.toString() ?? '';

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
}
