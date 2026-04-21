part of 'customer_corrections_cubit.dart';

class CustomerCorrectionsState extends Equatable {
  const CustomerCorrectionsState({
    required this.isLoading,
    required this.isSubmitting,
    required this.requests,
    required this.errorMessage,
  });

  const CustomerCorrectionsState.initial()
    : isLoading = false,
      isSubmitting = false,
      requests = const <Map<String, dynamic>>[],
      errorMessage = null;

  final bool isLoading;
  final bool isSubmitting;
  final List<Map<String, dynamic>> requests;
  final String? errorMessage;

  CustomerCorrectionsState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<Map<String, dynamic>>? requests,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CustomerCorrectionsState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      requests: requests ?? this.requests,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [isLoading, isSubmitting, requests, errorMessage];
}
