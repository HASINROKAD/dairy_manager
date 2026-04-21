part of 'customer_dispute_cubit.dart';

class CustomerDisputeState extends Equatable {
  const CustomerDisputeState({
    required this.isLoading,
    required this.isSubmitting,
    required this.logs,
    required this.disputes,
    required this.selectedLogId,
    required this.disputeType,
    required this.errorMessage,
  });

  const CustomerDisputeState.initial()
    : isLoading = false,
      isSubmitting = false,
      logs = const <LedgerEntry>[],
      disputes = const <Map<String, dynamic>>[],
      selectedLogId = '',
      disputeType = 'other',
      errorMessage = null;

  final bool isLoading;
  final bool isSubmitting;
  final List<LedgerEntry> logs;
  final List<Map<String, dynamic>> disputes;
  final String selectedLogId;
  final String disputeType;
  final String? errorMessage;

  CustomerDisputeState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<LedgerEntry>? logs,
    List<Map<String, dynamic>>? disputes,
    String? selectedLogId,
    String? disputeType,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CustomerDisputeState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      logs: logs ?? this.logs,
      disputes: disputes ?? this.disputes,
      selectedLogId: selectedLogId ?? this.selectedLogId,
      disputeType: disputeType ?? this.disputeType,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isSubmitting,
    logs,
    disputes,
    selectedLogId,
    disputeType,
    errorMessage,
  ];
}
