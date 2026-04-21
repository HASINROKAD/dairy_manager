import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/constant/widgets/app_shared_widgets.dart';
import '../../../milk/data/repositories/milk_repository.dart';

part 'seller_workflow_state.dart';

class SellerWorkflowCubit extends Cubit<SellerWorkflowState> {
  SellerWorkflowCubit({required MilkRepository repository})
    : _repository = repository,
      super(const SellerWorkflowState.initial());

  final MilkRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final responses = await Future.wait<dynamic>([
        _repository.fetchSellerDeliveryDisputes(),
        _repository.fetchSellerCorrectionRequests(),
        _repository.fetchSellerLedgerLogs(),
      ]);

      final disputesPayload = responses[0] as Map<String, dynamic>;
      final correctionPayload = responses[1] as Map<String, dynamic>;
      final logsPayload = responses[2] as Map<String, dynamic>;

      final disputes =
          (disputesPayload['disputes'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);
      final correctionRequests =
          (correctionPayload['requests'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);
      final logs = (logsPayload['logs'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

      emit(
        state.copyWith(
          isLoading: false,
          disputes: disputes,
          correctionRequests: correctionRequests,
          logs: logs,
          selectedLogId: logs.isNotEmpty ? '${logs.first['_id'] ?? ''}' : '',
          clearError: true,
        ),
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

  void setSelectedLogId(String logId) {
    emit(state.copyWith(selectedLogId: logId, clearError: true));
  }

  void setRequestedSlot(String slot) {
    emit(state.copyWith(requestedSlot: slot, clearError: true));
  }

  Future<void> resolveDispute({
    required String disputeId,
    required bool approve,
    String? note,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      await _repository.resolveSellerDeliveryDispute(
        disputeId: disputeId,
        status: approve ? 'resolved' : 'rejected',
        resolutionNote: note,
      );
      await load();
      emit(state.copyWith(isSubmitting: false));
    } catch (error) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: AppFeedback.formatError(error),
        ),
      );
    }
  }

  Future<void> createCorrectionRequest({
    required double requestedQuantityLitres,
    required String reason,
  }) async {
    final logId = state.selectedLogId.trim();
    if (logId.isEmpty) {
      emit(state.copyWith(errorMessage: 'Please select a log entry first.'));
      return;
    }

    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      emit(state.copyWith(errorMessage: 'Please enter a reason.'));
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      await _repository.createSellerCorrectionRequest(
        logId: logId,
        requestedSlot: state.requestedSlot,
        requestedQuantityLitres: requestedQuantityLitres,
        reason: normalizedReason,
      );
      await load();
      emit(state.copyWith(isSubmitting: false));
    } catch (error) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: AppFeedback.formatError(error),
        ),
      );
    }
  }
}
