part of 'delivery_bloc.dart';

enum DeliveryStatus { initial, loading, loaded, submitting, failure }

class DeliveryState extends Equatable {
  const DeliveryState({
    required this.status,
    required this.items,
    this.errorMessage,
  });

  const DeliveryState.initial()
    : this(status: DeliveryStatus.initial, items: const <DeliverySheetItem>[]);

  final DeliveryStatus status;
  final List<DeliverySheetItem> items;
  final String? errorMessage;

  DeliveryState copyWith({
    DeliveryStatus? status,
    List<DeliverySheetItem>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DeliveryState(
      status: status ?? this.status,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, items, errorMessage];
}
