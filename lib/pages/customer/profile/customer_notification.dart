import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/notification_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/notification_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Helper to parse color from hex string
Color parseColor(dynamic color) {
  if (color is int) return Color(color);
  if (color is String && color.startsWith('#')) {
    final hex = color.replaceFirst('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    } else if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
  }
  return Colors.blueGrey;
}

// Helper to parse icon from string
IconData parseIcon(String icon) {
  switch (icon) {
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

// Helper to parse timestamp
DateTime parseTimestamp(dynamic ts) {
  if (ts is DateTime) return ts;
  if (ts is String) {
    try {
      return DateTime.parse(ts);
    } catch (_) {}
  }
  return DateTime.now();
}

class CustomerNotificationScreen extends StatefulWidget {
  final bool showAppBar;

  const CustomerNotificationScreen({super.key, this.showAppBar = true});

  @override
  State<CustomerNotificationScreen> createState() =>
      _CustomerNotificationScreenState();
}

class _CustomerNotificationScreenState
    extends State<CustomerNotificationScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  bool _selectionMode = false;
  Set<int> _selectedNotificationIds = {};
  int? customerUserId;
  bool _showOnlyTickets = false;

  @override
  void initState() {
    super.initState();
    _loadUserIdAndNotifications();
  }

  Future<void> _loadUserIdAndNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      customerUserId = prefs.getInt('user_id');
    });
    if (customerUserId != null) {
      await _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      if (customerUserId != null) {
        final notifications =
            await NotificationService.getCustomerNotifications(customerUserId!);

        setState(() {
          _notifications =
              notifications
                  .map(
                    (n) => {
                      ...n,
                      'isRead': n['isRead'] ?? n['is_read'] == 1,
                      'icon': n['icon'], // Keep the original icon string
                      'iconData': parseIcon(
                        n['icon'] ?? 'notifications',
                      ), // Store parsed IconData
                      'color': parseColor(n['color']),
                      'timestamp': parseTimestamp(
                        n['created_at'] ?? n['timestamp'],
                      ),
                    },
                  )
                  .toList();
        });
      } else {
        setState(() {
          _notifications = [];
        });
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _notifications = [];
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _ticketNotifications =>
      _notifications.where((n) => n['type'] == 'ticket_created').toList();

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
      await NotificationService.deleteCustomerNotification(id);
    }
    await _loadNotifications();
    _exitSelectionMode();
  }

  Future<void> _markAsRead(int notificationId) async {
    final index = _notifications.indexWhere((n) => n['id'] == notificationId);
    if (index != -1) {
      final isCurrentlyRead = _notifications[index]['isRead'] ?? false;
      setState(() {
        _notifications[index]['isRead'] = !isCurrentlyRead;
      });
      if (!isCurrentlyRead) {
        await NotificationService.markCustomerNotificationRead(notificationId);
      } else {
        await NotificationService.markCustomerNotificationUnread(
          notificationId,
        );
      }
      await Provider.of<NotificationProvider>(context, listen: false).refresh();
      await _loadNotifications();
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
                  await Provider.of<NotificationProvider>(
                    context,
                    listen: false,
                  ).clearAll();
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
    final notificationsToShow =
        _showOnlyTickets ? _ticketNotifications : _notifications;
    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
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
                        : const Text('Notifications'),
                centerTitle: true,
                elevation: 2,
                backgroundColor: const Color(0xFF133343),
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(15),
                  ),
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
                                  await NotificationService.markCustomerNotificationRead(
                                    id,
                                  );
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
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: !_showOnlyTickets,
                        onSelected: (selected) {
                          setState(() {
                            _showOnlyTickets = false;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Tickets'),
                        selected: _showOnlyTickets,
                        onSelected: (selected) {
                          setState(() {
                            _showOnlyTickets = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              )
              : null,
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : notificationsToShow.isEmpty
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
                  itemCount: notificationsToShow.length,
                  itemBuilder: (context, index) {
                    final notification = notificationsToShow[index];
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
                                await NotificationService.deleteNotification(
                                  notification['id'],
                                );
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
                                            iconName:
                                                deletedNotification['icon'], // Use the original icon string
                                            color: deletedNotification['color'],
                                            data: deletedNotification['data'],
                                          );
                                          await Provider.of<
                                            NotificationProvider
                                          >(context, listen: false).refresh();
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
                                    color: notification['color'].withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    notification['iconData'], // Use parsed IconData
                                    color: notification['color'],
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
      ),
    );
  }
}
