import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/notification_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/notification_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  bool _selectionMode = false;
  Set<int> _selectedNotificationIds = {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      // For backend integration, use the backend version of getNotifications
      // final prefs = await SharedPreferences.getInstance();
      // final userId = prefs.getInt('user_id');
      // if (userId == null) throw Exception('User not logged in');
      // final notifications = await NotificationService.getNotifications(userId);
      final notifications = await NotificationService.getNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
        _selectedNotificationIds.clear();
        _selectionMode = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _notifications = [];
        _isLoading = false;
        _selectedNotificationIds.clear();
        _selectionMode = false;
      });
    }
  }

  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedNotificationIds.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedNotificationIds.clear();
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedNotificationIds =
            _notifications.map<int>((n) => n['id'] as int).toSet();
      } else {
        _selectedNotificationIds.clear();
      }
    });
  }

  void _toggleSelectNotification(int id) {
    setState(() {
      if (_selectedNotificationIds.contains(id)) {
        _selectedNotificationIds.remove(id);
      } else {
        _selectedNotificationIds.add(id);
      }
    });
  }

  Future<void> _deleteSelectedNotifications() async {
    final idsToDelete = _selectedNotificationIds.toList();
    for (final id in idsToDelete) {
      await NotificationService.deleteNotification(id);
    }
    await Provider.of<NotificationProvider>(context, listen: false).refresh();
    await _loadNotifications();
    _exitSelectionMode();
  }

  Future<void> _markAsRead(int notificationId) async {
    // Find the notification to check its current read status
    final notification = _notifications.firstWhere(
      (n) => n['id'] == notificationId,
      orElse: () => {},
    );

    if (notification.isNotEmpty) {
      final isCurrentlyRead = notification['isRead'] ?? false;

      if (isCurrentlyRead) {
        // If currently read, mark as unread
        await NotificationService.markAsRead(notificationId);
        // Update the local state immediately for better UX
        setState(() {
          final index = _notifications.indexWhere(
            (n) => n['id'] == notificationId,
          );
          if (index != -1) {
            _notifications[index]['isRead'] = false;
          }
        });
      } else {
        // If currently unread, mark as read
        await NotificationService.markAsRead(notificationId);
        // Update the local state immediately for better UX
        setState(() {
          final index = _notifications.indexWhere(
            (n) => n['id'] == notificationId,
          );
          if (index != -1) {
            _notifications[index]['isRead'] = true;
          }
        });
      }

      // Refresh the notification provider
      await Provider.of<NotificationProvider>(context, listen: false).refresh();
    }
  }

  void _clearAllNotifications() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear All Notifications'),
            content: const Text(
              'Are you sure you want to clear all notifications?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  // Delete each notification individually
                  for (final notification in _notifications) {
                    await NotificationService.deleteNotification(
                      notification['id'],
                    );
                  }
                  await Provider.of<NotificationProvider>(
                    context,
                    listen: false,
                  ).refresh();
                  Navigator.pop(context);
                  await _loadNotifications();
                },
                child: const Text('Clear'),
              ),
            ],
          ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading:
            _selectionMode
                ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _exitSelectionMode,
                  tooltip: 'Cancel',
                )
                : null,
        title:
            _selectionMode
                ? Text(
                  _selectedNotificationIds.length == 0
                      ? 'Select'
                      : '${_selectedNotificationIds.length} selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                )
                : const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF133343),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          if (_selectionMode)
            IconButton(
              icon: const Icon(
                Icons.mark_email_read_outlined,
                color: Colors.white,
              ),
              onPressed:
                  _selectedNotificationIds.isNotEmpty
                      ? () async {
                        for (final id in _selectedNotificationIds) {
                          await Provider.of<NotificationProvider>(
                            context,
                            listen: false,
                          ).markAsRead(id);
                        }
                        await _loadNotifications();
                        _exitSelectionMode();
                      }
                      : null,
              tooltip: 'Mark selected as read',
            )
          else if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.mark_email_read_outlined),
              onPressed: _enterSelectionMode,
              tooltip: 'Select notifications',
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _notifications.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'re all caught up!',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  final id = notification['id'] as int;
                  return Dismissible(
                    key: Key(id.toString()),
                    direction:
                        _selectionMode
                            ? DismissDirection.none
                            : DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      color: Colors.red,
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed:
                        _selectionMode
                            ? null
                            : (direction) async {
                              final deletedNotification = notification;
                              await NotificationService.deleteNotification(id);
                              await Provider.of<NotificationProvider>(
                                context,
                                listen: false,
                              ).refresh();
                              await _loadNotifications();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${notification['title']} dismissed',
                                    ),
                                    action: SnackBarAction(
                                      label: 'Undo',
                                      onPressed: () async {
                                        await NotificationService.createNotification(
                                          title: deletedNotification['title'],
                                          message:
                                              deletedNotification['message'],
                                          type: deletedNotification['type'],
                                          icon: deletedNotification['icon'],
                                          color: deletedNotification['color'],
                                          data: deletedNotification['data'],
                                        );
                                        await Provider.of<NotificationProvider>(
                                          context,
                                          listen: false,
                                        ).refresh();
                                        await _loadNotifications();
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                    child: Card(
                      elevation: (notification['isRead'] ?? false) ? 0 : 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color:
                              (notification['isRead'] ?? false)
                                  ? Colors.grey[200]!
                                  : notification['color'].withOpacity(0.5),
                          width: (notification['isRead'] ?? false) ? 1 : 2,
                        ),
                      ),
                      child: InkWell(
                        onTap:
                            _selectionMode
                                ? () => _toggleSelectNotification(id)
                                : () => _markAsRead(id),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_selectionMode)
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Checkbox(
                                    value: _selectedNotificationIds.contains(
                                      id,
                                    ),
                                    onChanged:
                                        (value) =>
                                            _toggleSelectNotification(id),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: notification['color'].withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  notification['icon'],
                                  color: notification['color'],
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            notification['title'],
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight:
                                                  (notification['isRead'] ??
                                                          false)
                                                      ? FontWeight.normal
                                                      : FontWeight.bold,
                                              color:
                                                  (notification['isRead'] ??
                                                          false)
                                                      ? Colors.grey[600]
                                                      : Colors.black,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _getTimeAgo(
                                            notification['timestamp'],
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notification['message'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!_selectionMode &&
                                  !(notification['isRead'] ?? false))
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: notification['color'],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
