part of 'seller_join_requests_cubit.dart';

class SellerJoinRequestsState extends Equatable {
  const SellerJoinRequestsState({
    required this.isLoading,
    required this.requests,
    this.errorMessage,
    this.actingRequestId,
    this.actionMessage,
    this.actionError,
    required this.actionVersion,
  });

  const SellerJoinRequestsState.initial()
    : this(
        isLoading: false,
        requests: const <JoinRequestItem>[],
        actionVersion: 0,
      );

  final bool isLoading;
  final List<JoinRequestItem> requests;
  final String? errorMessage;
  final String? actingRequestId;
  final String? actionMessage;
  final String? actionError;
  final int actionVersion;

  SellerJoinRequestsState copyWith({
    bool? isLoading,
    List<JoinRequestItem>? requests,
    String? errorMessage,
    String? actingRequestId,
    String? actionMessage,
    String? actionError,
    int? actionVersion,
    bool clearError = false,
    bool clearActionMessage = false,
    bool clearActionError = false,
  }) {
    return SellerJoinRequestsState(
      isLoading: isLoading ?? this.isLoading,
      requests: requests ?? this.requests,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      actingRequestId: actingRequestId ?? this.actingRequestId,
      actionMessage: clearActionMessage
          ? null
          : (actionMessage ?? this.actionMessage),
      actionError: clearActionError ? null : (actionError ?? this.actionError),
      actionVersion: actionVersion ?? this.actionVersion,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    requests,
    errorMessage,
    actingRequestId,
    actionMessage,
    actionError,
    actionVersion,
  ];
}
