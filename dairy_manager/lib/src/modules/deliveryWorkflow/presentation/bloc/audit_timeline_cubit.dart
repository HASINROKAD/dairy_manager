import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/constant/widgets/app_shared_widgets.dart';
import '../../../milk/data/repositories/milk_repository.dart';

part 'audit_timeline_state.dart';

class AuditTimelineCubit extends Cubit<AuditTimelineState> {
  AuditTimelineCubit({
    required MilkRepository repository,
    required bool isSeller,
  }) : _repository = repository,
       _isSeller = isSeller,
       super(const AuditTimelineState.initial());

  final MilkRepository _repository;
  final bool _isSeller;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final payload = _isSeller
          ? await _repository.fetchSellerDeliveryAudit()
          : await _repository.fetchMyLedgerAudit();

      final entries =
          (payload['entries'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);

      emit(
        state.copyWith(isLoading: false, entries: entries, clearError: true),
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
}
