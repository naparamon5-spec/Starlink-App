import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  int _unreadCount = 0;

  int get unreadCount => _unreadCount;

  NotificationProvider() {
    loadUnreadCount();
  }

  Future<void> loadUnreadCount() async {
    _unreadCount = await NotificationService.getUnreadCount();
    notifyListeners();
  }

  Future<void> markAsRead(int notificationId) async {
    await NotificationService.markAsRead(notificationId);
    await loadUnreadCount();
  }

  Future<void> clearAll() async {
    await NotificationService.clearAllNotifications();
    await loadUnreadCount();
  }

  // Call this after any notification change
  Future<void> refresh() async {
    await loadUnreadCount();
  }
}
