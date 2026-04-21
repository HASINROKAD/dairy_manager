import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/constant/widgets/app_shared_widgets.dart';
import '../../../milk/data/repositories/milk_repository.dart';

part 'customer_corrections_state.dart';

class CustomerCorrectionsCubit extends Cubit<CustomerCorrectionsState> {
  CustomerCorrectionsCubit({required MilkRepository repository})
    : _repository = repository,
      super(const CustomerCorrectionsState.initial());

  final MilkRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final payload = await _repository.fetchMyCorrectionRequests();
      final requests =
          (payload['requests'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);

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

  Future<void> approve({required String requestId, String? reviewNote}) async {
    await _review(requestId: requestId, reviewNote: reviewNote, approve: true);
  }

  Future<void> reject({required String requestId, String? reviewNote}) async {
    await _review(requestId: requestId, reviewNote: reviewNote, approve: false);
  }

  Future<void> _review({
    required String requestId,
    required bool approve,
    String? reviewNote,
  }) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      if (approve) {
        await _repository.approveMyCorrectionRequest(
          requestId: requestId,
          reviewNote: reviewNote,
        );
      } else {
        await _repository.rejectMyCorrectionRequest(
          requestId: requestId,
          reviewNote: reviewNote,
        );
      }

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
