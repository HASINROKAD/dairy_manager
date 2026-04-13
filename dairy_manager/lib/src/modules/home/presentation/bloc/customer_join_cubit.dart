import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/constant/widgets/app_shared_widgets.dart';
import '../../data/models/join_request_item.dart';
import '../../data/models/nearby_seller.dart';
import '../../data/repositories/home_repository.dart';

part 'customer_join_state.dart';

class CustomerJoinCubit extends Cubit<CustomerJoinState> {
  CustomerJoinCubit({required HomeRepository repository})
    : _repository = repository,
      super(const CustomerJoinState.initial());

  final HomeRepository _repository;

  Future<void> load({
    required double? latitude,
    required double? longitude,
  }) async {
    if (latitude == null || longitude == null) {
      final requests = await _repository.fetchMyJoinRequests();
      emit(
        state.copyWith(
          hasLocation: false,
          joinRequests: requests,
          isLoadingNearby: false,
          isLoadingRequests: false,
          clearNearbyError: true,
          clearRequestError: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        hasLocation: true,
        isLoadingNearby: true,
        isLoadingRequests: true,
        clearNearbyError: true,
        clearRequestError: true,
      ),
    );

    try {
      final results = await Future.wait<dynamic>([
        _repository.fetchNearbySellers(
          latitude: latitude,
          longitude: longitude,
          radiusKm: 5,
        ),
        _repository.fetchMyJoinRequests(),
      ]);

      emit(
        state.copyWith(
          nearbySellers: results[0] as List<NearbySeller>,
          joinRequests: results[1] as List<JoinRequestItem>,
          isLoadingNearby: false,
          isLoadingRequests: false,
          clearNearbyError: true,
          clearRequestError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoadingNearby: false,
          isLoadingRequests: false,
          nearbyError: AppFeedback.formatError(error),
          requestError: AppFeedback.formatError(error),
        ),
      );
    }
  }

  Future<void> refreshJoinRequests() async {
    emit(state.copyWith(isLoadingRequests: true, clearRequestError: true));

    try {
      final requests = await _repository.fetchMyJoinRequests();
      emit(
        state.copyWith(
          joinRequests: requests,
          isLoadingRequests: false,
          clearRequestError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoadingRequests: false,
          requestError: AppFeedback.formatError(error),
        ),
      );
    }
  }

  Future<void> sendJoinRequest(String sellerUserId) async {
    emit(
      state.copyWith(
        submittingSellerId: sellerUserId,
        clearActionMessage: true,
        clearActionError: true,
      ),
    );

    try {
      await _repository.sendJoinRequest(sellerUserId);
      final requests = await _repository.fetchMyJoinRequests();

      emit(
        state.copyWith(
          joinRequests: requests,
          submittingSellerId: '',
          actionMessage: 'Join request sent successfully.',
          actionVersion: state.actionVersion + 1,
          clearActionError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          submittingSellerId: '',
          actionError: AppFeedback.formatError(error),
          actionVersion: state.actionVersion + 1,
          clearActionMessage: true,
        ),
      );
    }
  }
}
