import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/constant/widgets/app_shared_widgets.dart';
import '../../data/models/app_notification_item.dart';
import '../../data/repositories/home_repository.dart';

part 'home_notifications_state.dart';

class HomeNotificationsCubit extends Cubit<HomeNotificationsState> {
  HomeNotificationsCubit({required HomeRepository repository})
    : _repository = repository,
      super(const HomeNotificationsState.initial());

  final HomeRepository _repository;

  Future<void> loadUnreadCount() async {
    try {
      final feed = await _repository.fetchNotifications(
        unreadOnly: true,
        limit: 1,
      );
      emit(state.copyWith(unreadCount: feed.unreadCount));
    } catch (_) {
      emit(state.copyWith(unreadCount: 0));
    }
  }

  Future<void> loadFeed() async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final feed = await _repository.fetchNotifications();
      emit(
        state.copyWith(
          isLoading: false,
          items: feed.items,
          unreadCount: feed.unreadCount,
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

  Future<void> markRead(String notificationId) async {
    await _repository.markNotificationRead(notificationId);
    await loadFeed();
  }

  Future<void> markAllRead() async {
    await _repository.markAllNotificationsRead();
    await loadFeed();
  }
}
