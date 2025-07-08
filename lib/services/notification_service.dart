import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static const String _notificationsKey = 'app_notifications';
  static const String _unreadCountKey = 'unread_notifications_count';

  // Create a new notification
  static Future<void> createNotification({
    required String title,
    required String message,
    required String type,
    required IconData icon,
    required Color color,
    Map<String, dynamic>? data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> notifications = prefs.getStringList(_notificationsKey) ?? [];

      final notification = {
        'id': DateTime.now().millisecondsSinceEpoch,
        'type': type,
        'title': title,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
        'icon': icon.codePoint,
        'color': color.value,
        'data': data,
      };

      notifications.insert(0, jsonEncode(notification));

      // Keep only the last 100 notifications
      if (notifications.length > 100) {
        notifications = notifications.take(100).toList();
      }

      await prefs.setStringList(_notificationsKey, notifications);
      await _updateUnreadCount();
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  // Get all notifications
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> notifications = prefs.getStringList(_notificationsKey) ?? [];

      return notifications.map((notification) {
        final data = jsonDecode(notification) as Map<String, dynamic>;
        return {
          ...data,
          'icon': IconData(data['icon'] as int, fontFamily: 'MaterialIcons'),
          'color': Color(data['color'] as int),
          'timestamp': DateTime.parse(data['timestamp'] as String),
        };
      }).toList();
    } catch (e) {
      print('Error getting notifications: $e');
      return [];
    }
  }

  // Mark notification as read
  static Future<void> markAsRead(int notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> notifications = prefs.getStringList(_notificationsKey) ?? [];

      for (int i = 0; i < notifications.length; i++) {
        final data = jsonDecode(notifications[i]);
        if (data['id'] == notificationId) {
          data['isRead'] = true;
          notifications[i] = jsonEncode(data);
          break;
        }
      }

      await prefs.setStringList(_notificationsKey, notifications);
      await _updateUnreadCount();
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  static Future<void> markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> notifications = prefs.getStringList(_notificationsKey) ?? [];

      for (int i = 0; i < notifications.length; i++) {
        final data = jsonDecode(notifications[i]);
        data['isRead'] = true;
        notifications[i] = jsonEncode(data);
      }

      await prefs.setStringList(_notificationsKey, notifications);
      await _updateUnreadCount();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Delete a notification
  static Future<void> deleteNotification(int notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> notifications = prefs.getStringList(_notificationsKey) ?? [];

      notifications.removeWhere((notification) {
        final data = jsonDecode(notification);
        return data['id'] == notificationId;
      });

      await prefs.setStringList(_notificationsKey, notifications);
      await _updateUnreadCount();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // Clear all notifications
  static Future<void> clearAllNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_notificationsKey);
      await prefs.remove(_unreadCountKey);
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }

  // Get unread count
  static Future<int> getUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_unreadCountKey) ?? 0;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  // Update unread count
  static Future<void> _updateUnreadCount() async {
    try {
      final notifications = await getNotifications();
      final unreadCount = notifications.where((n) => !n['isRead']).length;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_unreadCountKey, unreadCount);
    } catch (e) {
      print('Error updating unread count: $e');
    }
  }

  // Create ticket acceptance notification
  static Future<void> createTicketAcceptanceNotification({
    required String ticketId,
    required String ticketType,
    required String customerName,
  }) async {
    await createNotification(
      title: 'Ticket Accepted',
      message:
          'Ticket #$ticketId ($ticketType) has been accepted by $customerName',
      type: 'ticket_acceptance',
      icon: Icons.check_circle,
      color: Colors.green,
      data: {
        'ticket_id': ticketId,
        'ticket_type': ticketType,
        'customer_name': customerName,
        'action': 'ticket_accepted',
      },
    );
  }

  // Create ticket resolution notification
  static Future<void> createTicketResolutionNotification({
    required String ticketId,
    required String ticketType,
    required String customerName,
  }) async {
    await createNotification(
      title: 'Ticket Resolved',
      message:
          'Ticket #$ticketId ($ticketType) has been resolved by $customerName',
      type: 'ticket_resolution',
      icon: Icons.task_alt,
      color: Colors.blue,
      data: {
        'ticket_id': ticketId,
        'ticket_type': ticketType,
        'customer_name': customerName,
        'action': 'ticket_resolved',
      },
    );
  }

  // Create ticket closure notification
  static Future<void> createTicketClosureNotification({
    required String ticketId,
    required String ticketType,
    required String customerName,
  }) async {
    await createNotification(
      title: 'Ticket Closed',
      message:
          'Ticket #$ticketId ($ticketType) has been closed by $customerName',
      type: 'ticket_closure',
      icon: Icons.cancel,
      color: Colors.red,
      data: {
        'ticket_id': ticketId,
        'ticket_type': ticketType,
        'customer_name': customerName,
        'action': 'ticket_closed',
      },
    );
  }
}
