part of 'delivery_bloc.dart';

sealed class DeliveryEvent extends Equatable {
  const DeliveryEvent();

  @override
  List<Object?> get props => [];
}

final class LoadDailySheet extends DeliveryEvent {
  const LoadDailySheet();
}

final class IncrementQty extends DeliveryEvent {
  const IncrementQty(this.customerId);

  final String customerId;

  @override
  List<Object?> get props => [customerId];
}

final class DecrementQty extends DeliveryEvent {
  const DecrementQty(this.customerId);

  final String customerId;

  @override
  List<Object?> get props => [customerId];
}

final class ConfirmBulkDelivery extends DeliveryEvent {
  const ConfirmBulkDelivery();
}
