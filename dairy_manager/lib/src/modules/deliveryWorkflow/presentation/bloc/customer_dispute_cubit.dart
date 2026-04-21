import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/constant/widgets/app_shared_widgets.dart';
import '../../../milk/data/models/ledger_entry.dart';
import '../../../milk/data/repositories/milk_repository.dart';

part 'customer_dispute_state.dart';

class CustomerDisputeCubit extends Cubit<CustomerDisputeState> {
  CustomerDisputeCubit({required MilkRepository repository})
    : _repository = repository,
      super(const CustomerDisputeState.initial());

  final MilkRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final responses = await Future.wait<dynamic>([
        _repository.fetchMyLedger(),
        _repository.fetchMyLedgerDisputes(),
      ]);

      final logs = responses[0] as List<LedgerEntry>;
      final disputePayload = responses[1] as Map<String, dynamic>;
      final disputes =
          (disputePayload['disputes'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);

      emit(
        state.copyWith(
          isLoading: false,
          logs: logs,
          disputes: disputes,
          selectedLogId: logs.isNotEmpty ? logs.first.id : '',
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

  void setDisputeType(String disputeType) {
    emit(state.copyWith(disputeType: disputeType, clearError: true));
  }

  Future<void> submitDispute({required String message}) async {
    final logId = state.selectedLogId.trim();
    if (logId.isEmpty) {
      emit(
        state.copyWith(
          errorMessage: 'Please select a ledger entry to dispute.',
        ),
      );
      return;
    }

    final trimmedMessage = message.trim();
    if (trimmedMessage.isEmpty) {
      emit(state.copyWith(errorMessage: 'Please enter dispute details.'));
      return;
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      await _repository.createMyLedgerDispute(
        logId: logId,
        disputeType: state.disputeType,
        message: trimmedMessage,
      );

      final disputePayload = await _repository.fetchMyLedgerDisputes();
      final disputes =
          (disputePayload['disputes'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);

      emit(
        state.copyWith(
          isSubmitting: false,
          disputes: disputes,
          clearError: true,
        ),
      );
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
