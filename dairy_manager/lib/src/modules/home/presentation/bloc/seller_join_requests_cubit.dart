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
  static const _unset = Object();

  String _sortBy = 'newest';
  String _area = '';
  double? _minQuantityLitres;
  double? _maxDistanceKm;

  Future<void> loadPending({
    String? sortBy,
    String? area,
    Object? minQuantityLitres = _unset,
    Object? maxDistanceKm = _unset,
  }) async {
    if (sortBy != null) {
      _sortBy = sortBy;
    }
    if (area != null) {
      _area = area;
    }
    if (minQuantityLitres != _unset) {
      _minQuantityLitres = minQuantityLitres as double?;
    }
    if (maxDistanceKm != _unset) {
      _maxDistanceKm = maxDistanceKm as double?;
    }

    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final requests = await _repository.fetchSellerJoinRequests(
        status: 'pending',
        sortBy: _sortBy,
        area: _area.trim().isEmpty ? null : _area.trim(),
        minQuantityLitres: _minQuantityLitres,
        maxDistanceKm: _maxDistanceKm,
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
        sortBy: _sortBy,
        area: _area.trim().isEmpty ? null : _area.trim(),
        minQuantityLitres: _minQuantityLitres,
        maxDistanceKm: _maxDistanceKm,
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
