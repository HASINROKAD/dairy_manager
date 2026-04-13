import 'app_notification_item.dart';

class NotificationFeed {
  NotificationFeed({required this.items, required this.unreadCount});

  final List<AppNotificationItem> items;
  final int unreadCount;
}
