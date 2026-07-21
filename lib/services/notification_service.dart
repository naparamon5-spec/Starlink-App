import 'dart:convert';
import 'dart:io' show HttpClient;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:starlink_app/services/api_service.dart';

class NotificationService {
  static const String _notificationsKey = 'app_notifications';
  static const String _unreadCountKey = 'unread_notifications_count';

  static String get baseUrl => ApiService.baseUrl;

  // ─── Remote notification endpoint ──────────────────────────────────────────
  // The legacy monolith (`api.php?action=...`) has been removed from the
  // backend, so the old calls now return HTTP 404. All remote notification
  // calls go through this single base path against the new `/v1` REST API.
  //
  // ⚠️ This path is UNVERIFIED: the `/v1` resource namespaces are auth-gated,
  // so the exact route could not be confirmed by probing. If notifications
  // still 404, set this to the real route from the backend and everything else
  // in this file follows automatically. Candidates seen in the wild:
  //   /v1/notifications            (top-level resource)
  //   /v1/users/<id>/notifications (nested under user)
  static const String _notificationsBase = '/v1/notifications';

  // Auth headers built from the stored bearer token, matching ApiService.
  static Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Extracts a list of notification maps from any of the response shapes the
  // backend might use: a bare JSON array, `{data: [...]}`, or the legacy
  // `{status: 'success', data: [...]}` envelope.
  static List<Map<String, dynamic>> _asNotificationList(dynamic decoded) {
    dynamic list = decoded;
    if (decoded is Map) {
      list = decoded['data'] ?? decoded['notifications'] ?? decoded['items'];
    }
    if (list is! List) return [];
    return list.whereType<Map>().map((n) {
      return <String, dynamic>{
        ...Map<String, dynamic>.from(n),
        'id': n['id'] is String ? int.tryParse(n['id']) ?? 0 : n['id'] as int? ?? 0,
        'is_read':
            n['is_read'] is String
                ? int.tryParse(n['is_read']) ??
                    (n['is_read'] == 'false' ? 0 : 1)
                : n['is_read'] is bool
                ? (n['is_read'] ? 1 : 0)
                : n['is_read'] as int? ?? 0,
      };
    }).toList();
  }

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
      debugPrint('Error creating notification: $e');
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
      debugPrint('Error getting notifications: $e');
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
      debugPrint('Error marking notification as read: $e');
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
      debugPrint('Error marking all notifications as read: $e');
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
      debugPrint('Error deleting notification: $e');
    }
  }

  // Clear all notifications
  static Future<void> clearAllNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_notificationsKey);
      await prefs.remove(_unreadCountKey);
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
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
      debugPrint('Error getting unread count from backend: $e');
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
      debugPrint('Error updating unread count: $e');
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
      final headers = await _authHeaders();
      final response = await _client.get(
        Uri.parse('$baseUrl$_notificationsBase?user_id=$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return _asNotificationList(json.decode(response.body));
      }

      if (response.statusCode == 404) {
        // Endpoint not available on the backend yet — treat as "no
        // notifications" so the UI shows an empty state instead of an error.
        debugPrint(
          'Notifications endpoint not found ($baseUrl$_notificationsBase). '
          'Update NotificationService._notificationsBase to the real route.',
        );
        return [];
      }

      debugPrint(
        'getCustomerNotifications HTTP ${response.statusCode}: ${response.body}',
      );
      return [];
    } catch (e) {
      debugPrint('Error in getCustomerNotifications: $e');
      return [];
    }
  }

  // Create a notification for a customer
  static Future<void> createCustomerNotification(
    Map<String, dynamic> notification,
  ) async {
    await _sendNotificationWrite(
      method: 'POST',
      uri: Uri.parse('$baseUrl$_notificationsBase'),
      body: notification,
      action: 'create notification',
    );
  }

  // Mark notification as read
  static Future<void> markCustomerNotificationRead(int id) async {
    await _sendNotificationWrite(
      method: 'PATCH',
      uri: Uri.parse('$baseUrl$_notificationsBase/$id/read'),
      action: 'mark notification as read',
    );
  }

  // Mark notification as unread
  static Future<void> markCustomerNotificationUnread(int id) async {
    await _sendNotificationWrite(
      method: 'PATCH',
      uri: Uri.parse('$baseUrl$_notificationsBase/$id/unread'),
      action: 'mark notification as unread',
    );
  }

  // Delete notification
  static Future<void> deleteCustomerNotification(int id) async {
    await _sendNotificationWrite(
      method: 'DELETE',
      uri: Uri.parse('$baseUrl$_notificationsBase/$id'),
      action: 'delete notification',
    );
  }

  // Shared write path for the notification mutators. Treats a 2xx as success
  // regardless of response envelope, and surfaces a clear error otherwise.
  static Future<void> _sendNotificationWrite({
    required String method,
    required Uri uri,
    required String action,
    Map<String, dynamic>? body,
  }) async {
    try {
      final headers = await _authHeaders();
      final encodedBody = body == null ? null : json.encode(body);

      late final http.Response response;
      switch (method) {
        case 'POST':
          response = await _client.post(uri, headers: headers, body: encodedBody);
          break;
        case 'PATCH':
          response = await _client.patch(uri, headers: headers, body: encodedBody);
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: headers, body: encodedBody);
          break;
        default:
          throw Exception('Unsupported method $method');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      if (response.statusCode == 404) {
        throw Exception(
          'Notifications endpoint not available ($uri). '
          'Update NotificationService._notificationsBase to the real route.',
        );
      }

      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    } catch (e) {
      debugPrint('Error trying to $action: $e');
      throw Exception('Failed to $action: $e');
    }
  }
}
