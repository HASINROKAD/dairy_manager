part of 'customer_join_cubit.dart';

class CustomerJoinState extends Equatable {
  const CustomerJoinState({
    required this.hasLocation,
    required this.isLoadingNearby,
    required this.isLoadingRequests,
    required this.nearbySellers,
    required this.joinRequests,
    this.nearbyError,
    this.requestError,
    this.submittingSellerId,
    this.actionMessage,
    this.actionError,
    required this.actionVersion,
  });

  const CustomerJoinState.initial()
    : this(
        hasLocation: true,
        isLoadingNearby: false,
        isLoadingRequests: false,
        nearbySellers: const <NearbySeller>[],
        joinRequests: const <JoinRequestItem>[],
        actionVersion: 0,
      );

  final bool hasLocation;
  final bool isLoadingNearby;
  final bool isLoadingRequests;
  final List<NearbySeller> nearbySellers;
  final List<JoinRequestItem> joinRequests;
  final String? nearbyError;
  final String? requestError;
  final String? submittingSellerId;
  final String? actionMessage;
  final String? actionError;
  final int actionVersion;

  CustomerJoinState copyWith({
    bool? hasLocation,
    bool? isLoadingNearby,
    bool? isLoadingRequests,
    List<NearbySeller>? nearbySellers,
    List<JoinRequestItem>? joinRequests,
    String? nearbyError,
    String? requestError,
    String? submittingSellerId,
    String? actionMessage,
    String? actionError,
    int? actionVersion,
    bool clearNearbyError = false,
    bool clearRequestError = false,
    bool clearActionMessage = false,
    bool clearActionError = false,
  }) {
    return CustomerJoinState(
      hasLocation: hasLocation ?? this.hasLocation,
      isLoadingNearby: isLoadingNearby ?? this.isLoadingNearby,
      isLoadingRequests: isLoadingRequests ?? this.isLoadingRequests,
      nearbySellers: nearbySellers ?? this.nearbySellers,
      joinRequests: joinRequests ?? this.joinRequests,
      nearbyError: clearNearbyError ? null : (nearbyError ?? this.nearbyError),
      requestError: clearRequestError
          ? null
          : (requestError ?? this.requestError),
      submittingSellerId: submittingSellerId ?? this.submittingSellerId,
      actionMessage: clearActionMessage
          ? null
          : (actionMessage ?? this.actionMessage),
      actionError: clearActionError ? null : (actionError ?? this.actionError),
      actionVersion: actionVersion ?? this.actionVersion,
    );
  }

  @override
  List<Object?> get props => [
    hasLocation,
    isLoadingNearby,
    isLoadingRequests,
    nearbySellers,
    joinRequests,
    nearbyError,
    requestError,
    submittingSellerId,
    actionMessage,
    actionError,
    actionVersion,
  ];
}
