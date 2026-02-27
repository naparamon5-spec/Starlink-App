import 'dart:convert';
import 'dart:io' show Platform, HttpClient, X509Certificate;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';
// import '../config/ssl_config.dart'; // Commented out as it’s not provided

class NotificationService {
  static const String _notificationsKey = 'app_notifications';
  static const String _unreadCountKey = 'unread_notifications_count';

  // Create a new notification
  static Future<void> createNotification({
    required String title,
    required String message,
    required String type,
    required String iconName, // now a string
    required Color color,
    Map<String, dynamic>? data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> notifications = prefs.getStringList(_notificationsKey) ?? [];

      final notification = {
        'id': DateTime.now().millisecondsSinceEpoch, // int
        'type': type,
        'title': title,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
        'icon': iconName, // store icon name as string
        'color': color.value, // int
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

  // Helper to map icon name string to IconData
  static IconData iconFromString(String iconName) {
    switch (iconName) {
      case 'check_circle':
        return Icons.check_circle;
      case 'task_alt':
        return Icons.task_alt;
      case 'cancel':
        return Icons.cancel;
      case 'confirmation_number':
        return Icons.confirmation_number;
      case 'info':
        return Icons.info;
      case 'warning':
        return Icons.warning;
      case 'notifications':
        return Icons.notifications;
      default:
        return Icons.notifications;
    }
  }

  // Get all notifications
  static Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> notifications = prefs.getStringList(_notificationsKey) ?? [];

      return notifications.map((notification) {
        final data = jsonDecode(notification) as Map<String, dynamic>;
        // Safely convert color from String or int to int
        int colorValue;
        if (data['color'] is String) {
          colorValue =
              int.tryParse(data['color']) ?? 0xFF000000; // Default to black
        } else {
          colorValue = data['color'] as int? ?? 0xFF000000;
        }
        // Ensure id is int
        int id;
        if (data['id'] is String) {
          id = int.tryParse(data['id']) ?? 0;
        } else {
          id = data['id'] as int? ?? 0;
        }
        return {
          ...data,
          'id': id,
          'icon': iconFromString(data['icon'] as String? ?? 'notifications'),
          'color': Color(colorValue),
          'timestamp': DateTime.parse(
            data['timestamp'] as String? ?? DateTime.now().toIso8601String(),
          ),
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
        final data = jsonDecode(notifications[i]) as Map<String, dynamic>;
        // Handle id as String or int
        int id;
        if (data['id'] is String) {
          id = int.tryParse(data['id']) ?? 0;
        } else {
          id = data['id'] as int? ?? 0;
        }
        if (id == notificationId) {
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
        final data = jsonDecode(notifications[i]) as Map<String, dynamic>;
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
        final data = jsonDecode(notification) as Map<String, dynamic>;
        int id;
        if (data['id'] is String) {
          id = int.tryParse(data['id']) ?? 0;
        } else {
          id = data['id'] as int? ?? 0;
        }
        return id == notificationId;
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

  // Get unread count from backend for customer
  static Future<int> getUnreadCount({int? userId}) async {
    try {
      // If userId is not provided, get it from SharedPreferences
      int? uid = userId;
      if (uid == null) {
        final prefs = await SharedPreferences.getInstance();
        // Handle user_id as String or int
        final storedUserId = prefs.get('user_id');
        if (storedUserId is String) {
          uid = int.tryParse(storedUserId);
        } else {
          uid = storedUserId as int?;
        }
        if (uid == null) return 0;
      }
      final notifications = await getCustomerNotifications(uid);
      final unreadCount =
          notifications.where((n) {
            final isRead = n['is_read'] ?? n['isRead'] ?? false;
            if (isRead is String) {
              return int.tryParse(isRead) == 0; // unread if "0"
            }
            if (isRead is int) return isRead == 0; // unread if 0
            if (isRead is bool) return !isRead; // unread if false
            return true; // treat as unread if unknown
          }).length;
      return unreadCount;
    } catch (e) {
      print('Error getting unread count from backend: $e');
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
      iconName: 'check_circle',
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
      iconName: 'task_alt',
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
      iconName: 'cancel',
      color: Colors.red,
      data: {
        'ticket_id': ticketId,
        'ticket_type': ticketType,
        'customer_name': customerName,
        'action': 'ticket_closed',
      },
    );
  }

  // BACKEND-BASED CUSTOMER NOTIFICATIONS
  static String get baseUrl {
    return 'https://starlink-api.ardentnetworks.com.ph/api/';
  }

  // Create a custom HTTP client that uses our SSL configuration
  static http.Client get _client {
    final httpClient =
        HttpClient()..connectionTimeout = const Duration(seconds: 15);
    return IOClient(httpClient);
  }

  // Fetch notifications for a specific user (customer)
  static Future<List<Map<String, dynamic>>> getCustomerNotifications(
    int userId,
  ) async {
    try {
      // Get stored token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final headers = <String, String>{'Content-Type': 'application/json'};

      // Add authorization header if token exists
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _client.get(
        Uri.parse('$baseUrl/api.php?action=get_notifications&user_id=$userId'),
        headers: headers,
      );

      // Check if response is valid JSON
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['status'] == 'success') {
            // Convert id and other potential String fields to int
            return List<Map<String, dynamic>>.from(data['data']).map((n) {
              return {
                ...n,
                'id':
                    n['id'] is String
                        ? int.tryParse(n['id']) ?? 0
                        : n['id'] as int? ?? 0,
                'is_read':
                    n['is_read'] is String
                        ? int.tryParse(n['is_read']) ??
                            (n['is_read'] == 'false' ? 0 : 1)
                        : n['is_read'] is bool
                        ? n['is_read']
                            ? 1
                            : 0
                        : n['is_read'] as int? ?? 0,
              };
            }).toList();
          } else {
            throw Exception(data['message'] ?? 'Failed to fetch notifications');
          }
        } catch (e) {
          print('Response body: ${response.body}');
          if (response.body.contains('<!doctype html>')) {
            throw Exception(
              'Server returned HTML instead of JSON. Check if the API endpoint is accessible.',
            );
          }
          throw Exception('Invalid response format from server: $e');
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      print('Error in getCustomerNotifications: $e');
      return [];
    }
  }

  // Create a notification for a customer
  static Future<void> createCustomerNotification(
    Map<String, dynamic> notification,
  ) async {
    try {
      // Get stored token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final headers = <String, String>{'Content-Type': 'application/json'};

      // Add authorization header if token exists
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/api.php?action=create_notification'),
        headers: headers,
        body: json.encode(notification),
      );

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['status'] != 'success') {
            throw Exception(data['message'] ?? 'Failed to create notification');
          }
        } catch (e) {
          print('Response body: ${response.body}');
          if (response.body.contains('<!doctype html>')) {
            throw Exception(
              'Server returned HTML instead of JSON. Check if the API endpoint is accessible.',
            );
          }
          throw Exception('Invalid response format from server: $e');
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      print('Error in createCustomerNotification: $e');
      throw Exception('Failed to create notification: $e');
    }
  }

  // Mark notification as read
  static Future<void> markCustomerNotificationRead(int id) async {
    try {
      // Get stored token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final headers = <String, String>{'Content-Type': 'application/json'};

      // Add authorization header if token exists
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/api.php?action=mark_notification_read'),
        headers: headers,
        body: json.encode({'id': id}),
      );

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['status'] != 'success') {
            throw Exception(data['message'] ?? 'Failed to mark as read');
          }
        } catch (e) {
          print('Response body: ${response.body}');
          if (response.body.contains('<!doctype html>')) {
            throw Exception(
              'Server returned HTML instead of JSON. Check if the API endpoint is accessible.',
            );
          }
          throw Exception('Invalid response format from server: $e');
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      print('Error in markCustomerNotificationRead: $e');
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  // Mark notification as unread
  static Future<void> markCustomerNotificationUnread(int id) async {
    try {
      // Get stored token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final headers = <String, String>{'Content-Type': 'application/json'};

      // Add authorization header if token exists
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/api.php?action=mark_notification_unread'),
        headers: headers,
        body: json.encode({'id': id}),
      );

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['status'] != 'success') {
            throw Exception(data['message'] ?? 'Failed to mark as unread');
          }
        } catch (e) {
          print('Response body: ${response.body}');
          if (response.body.contains('<!doctype html>')) {
            throw Exception(
              'Server returned HTML instead of JSON. Check if the API endpoint is accessible.',
            );
          }
          throw Exception('Invalid response format from server: $e');
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      print('Error in markCustomerNotificationUnread: $e');
      throw Exception('Failed to mark notification as unread: $e');
    }
  }

  // Delete notification
  static Future<void> deleteCustomerNotification(int id) async {
    try {
      // Get stored token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final headers = <String, String>{'Content-Type': 'application/json'};

      // Add authorization header if token exists
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/api.php?action=delete_notification'),
        headers: headers,
        body: json.encode({'id': id}),
      );

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['status'] != 'success') {
            throw Exception(data['message'] ?? 'Failed to delete notification');
          }
        } catch (e) {
          print('Response body: ${response.body}');
          if (response.body.contains('<!doctype html>')) {
            throw Exception(
              'Server returned HTML instead of JSON. Check if the API endpoint is accessible.',
            );
          }
          throw Exception('Invalid response format from server: $e');
        }
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      print('Error in deleteCustomerNotification: $e');
      throw Exception('Failed to delete notification: $e');
    }
  }
}
