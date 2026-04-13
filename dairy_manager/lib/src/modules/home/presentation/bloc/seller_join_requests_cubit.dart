import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/constant/widgets/app_shared_widgets.dart';
import '../../data/models/join_request_item.dart';
import '../../data/repositories/home_repository.dart';

part 'seller_join_requests_state.dart';

class SellerJoinRequestsCubit extends Cubit<SellerJoinRequestsState> {
  SellerJoinRequestsCubit({required HomeRepository repository})
    : _repository = repository,
      super(const SellerJoinRequestsState.initial());

  final HomeRepository _repository;

  Future<void> loadPending() async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final requests = await _repository.fetchSellerJoinRequests(
        status: 'pending',
      );
      emit(
        state.copyWith(isLoading: false, requests: requests, clearError: true),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: AppFeedback.formatError(error),
        ),
      );
    }
  }

  Future<void> review({
    required String requestId,
    required String action,
  }) async {
    emit(
      state.copyWith(
        actingRequestId: requestId,
        clearActionMessage: true,
        clearActionError: true,
      ),
    );

    try {
      await _repository.reviewJoinRequest(requestId: requestId, action: action);
      final requests = await _repository.fetchSellerJoinRequests(
        status: 'pending',
      );
      emit(
        state.copyWith(
          actingRequestId: '',
          requests: requests,
          actionMessage: 'Request ${action}ed successfully.',
          actionVersion: state.actionVersion + 1,
          clearActionError: true,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          actingRequestId: '',
          actionError: AppFeedback.formatError(error),
          actionVersion: state.actionVersion + 1,
          clearActionMessage: true,
        ),
      );
    }
  }
}
