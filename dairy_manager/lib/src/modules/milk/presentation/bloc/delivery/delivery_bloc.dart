import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../data/models/delivery_sheet_item.dart';
import '../../../data/repositories/milk_repository.dart';

part 'delivery_event.dart';
part 'delivery_state.dart';

class DeliveryBloc extends Bloc<DeliveryEvent, DeliveryState> {
  DeliveryBloc({required MilkRepository repository})
    : _repository = repository,
      super(const DeliveryState.initial()) {
    on<LoadDailySheet>(_onLoadDailySheet);
    on<IncrementQty>(_onIncrementQty);
    on<DecrementQty>(_onDecrementQty);
    on<ConfirmBulkDelivery>(_onConfirmBulkDelivery);
  }

  final MilkRepository _repository;

  Future<void> _onLoadDailySheet(
    LoadDailySheet event,
    Emitter<DeliveryState> emit,
  ) async {
    emit(state.copyWith(status: DeliveryStatus.loading, clearError: true));

    try {
      final sheet = await _repository.fetchDailySheet();
      emit(
        state.copyWith(
          status: DeliveryStatus.loaded,
          items: sheet,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: DeliveryStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  void _onIncrementQty(IncrementQty event, Emitter<DeliveryState> emit) {
    final updated = _mutateQuantity(
      state.items,
      event.customerId,
      (qty) => qty + 0.5,
    );
    emit(state.copyWith(items: updated));
  }

  void _onDecrementQty(DecrementQty event, Emitter<DeliveryState> emit) {
    final updated = _mutateQuantity(
      state.items,
      event.customerId,
      (qty) => qty > 0.5 ? qty - 0.5 : 0.5,
    );
    emit(state.copyWith(items: updated));
  }

  Future<void> _onConfirmBulkDelivery(
    ConfirmBulkDelivery event,
    Emitter<DeliveryState> emit,
  ) async {
    final customerIds = state.items.map((item) => item.customerId).toList();
    if (customerIds.isEmpty) {
      return;
    }

    // Optimistic UI update: mark as delivered before network call finishes.
    final optimisticItems = state.items
        .map((item) => item.copyWith(delivered: true))
        .toList(growable: false);

    emit(
      state.copyWith(
        status: DeliveryStatus.submitting,
        items: optimisticItems,
        clearError: true,
      ),
    );

    try {
      await _repository.confirmBulkDelivery(customerIds);
      emit(state.copyWith(status: DeliveryStatus.loaded));
    } catch (error) {
      emit(
        state.copyWith(
          status: DeliveryStatus.failure,
          errorMessage: error.toString(),
        ),
      );
      add(const LoadDailySheet());
    }
  }

  List<DeliverySheetItem> _mutateQuantity(
    List<DeliverySheetItem> items,
    String customerId,
    double Function(double current) updater,
  ) {
    return items
        .map((item) {
          if (item.customerId != customerId) {
            return item;
          }

          final nextQty = double.parse(
            updater(item.quantityLitres).toStringAsFixed(2),
          );
          return item.copyWith(quantityLitres: nextQty);
        })
        .toList(growable: false);
  }
}
