import 'package:bustan_amari/domain/entities/app_notification.dart';

abstract class INotificationRepository {
  Future<List<AppNotification>> getNotifications({int limit = 50});
  Future<int> getUnreadCount();
  Future<void> markAllAsRead();

  /// Emits once each time a new notification is inserted for the current user.
  Stream<void> watchNewNotifications();
}
