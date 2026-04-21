part of 'seller_workflow_cubit.dart';

class SellerWorkflowState extends Equatable {
  const SellerWorkflowState({
    required this.isLoading,
    required this.isSubmitting,
    required this.disputes,
    required this.correctionRequests,
    required this.logs,
    required this.selectedLogId,
    required this.requestedSlot,
    required this.errorMessage,
  });

  const SellerWorkflowState.initial()
    : isLoading = false,
      isSubmitting = false,
      disputes = const <Map<String, dynamic>>[],
      correctionRequests = const <Map<String, dynamic>>[],
      logs = const <Map<String, dynamic>>[],
      selectedLogId = '',
      requestedSlot = 'morning',
      errorMessage = null;

  final bool isLoading;
  final bool isSubmitting;
  final List<Map<String, dynamic>> disputes;
  final List<Map<String, dynamic>> correctionRequests;
  final List<Map<String, dynamic>> logs;
  final String selectedLogId;
  final String requestedSlot;
  final String? errorMessage;

  SellerWorkflowState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<Map<String, dynamic>>? disputes,
    List<Map<String, dynamic>>? correctionRequests,
    List<Map<String, dynamic>>? logs,
    String? selectedLogId,
    String? requestedSlot,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SellerWorkflowState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      disputes: disputes ?? this.disputes,
      correctionRequests: correctionRequests ?? this.correctionRequests,
      logs: logs ?? this.logs,
      selectedLogId: selectedLogId ?? this.selectedLogId,
      requestedSlot: requestedSlot ?? this.requestedSlot,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isSubmitting,
    disputes,
    correctionRequests,
    logs,
    selectedLogId,
    requestedSlot,
    errorMessage,
  ];
}
