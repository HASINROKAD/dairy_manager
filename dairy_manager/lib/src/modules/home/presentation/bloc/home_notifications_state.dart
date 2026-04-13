part of 'home_notifications_cubit.dart';

class HomeNotificationsState extends Equatable {
  const HomeNotificationsState({
    required this.unreadCount,
    required this.isLoading,
    required this.items,
    this.errorMessage,
  });

  const HomeNotificationsState.initial()
    : this(
        unreadCount: 0,
        isLoading: false,
        items: const <AppNotificationItem>[],
      );

  final int unreadCount;
  final bool isLoading;
  final List<AppNotificationItem> items;
  final String? errorMessage;

  HomeNotificationsState copyWith({
    int? unreadCount,
    bool? isLoading,
    List<AppNotificationItem>? items,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HomeNotificationsState(
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [unreadCount, isLoading, items, errorMessage];
}
