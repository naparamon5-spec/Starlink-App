import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/notification_provider.dart';
import '../../../services/notification_service.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);

Color _parseColor(dynamic color) {
  if (color is int) return Color(color);
  if (color is String && color.startsWith('#')) {
    final hex = color.replaceFirst('#', '');
    if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
    if (hex.length == 8) return Color(int.parse(hex, radix: 16));
  }
  return Colors.blueGrey;
}

IconData _parseIcon(String icon) {
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
    default:
      return Icons.notifications;
  }
}

DateTime _parseTimestamp(dynamic ts) {
  if (ts is DateTime) return ts;
  if (ts is String) {
    try {
      return DateTime.parse(ts);
    } catch (_) {}
  }
  return DateTime.now();
}

class AdminNotificationScreen extends StatefulWidget {
  const AdminNotificationScreen({super.key});

  @override
  State<AdminNotificationScreen> createState() =>
      _AdminNotificationScreenState();
}

class _AdminNotificationScreenState extends State<AdminNotificationScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  bool _selectionMode = false;
  final Set<int> _selectedNotificationIds = {};
  int? _userId;
  bool _showOnlyTickets = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadUserIdAndNotifications();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadUserIdAndNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final rawUserId = prefs.get('user_id');
    int? parsedUserId;
    if (rawUserId is int) {
      parsedUserId = rawUserId;
    } else if (rawUserId is String) {
      parsedUserId = int.tryParse(rawUserId);
    }

    setState(() => _userId = parsedUserId);
    if (_userId != null) {
      await _loadNotifications();
    } else {
      setState(() {
        _notifications = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      if (_userId != null) {
        final notifications =
            await NotificationService.getCustomerNotifications(_userId!);
        setState(() {
          _notifications =
              notifications
                  .map(
                    (n) => {
                      ...n,
                      'isRead': n['isRead'] ?? n['is_read'] == 1,
                      'icon': n['icon'],
                      'iconData': _parseIcon(
                        (n['icon'] ?? 'notifications').toString(),
                      ),
                      'color': _parseColor(n['color']),
                      'timestamp': _parseTimestamp(
                        n['created_at'] ?? n['timestamp'],
                      ),
                    },
                  )
                  .toList();
        });
      } else {
        setState(() => _notifications = []);
      }
    } catch (_) {
      setState(() => _notifications = []);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _animController.forward(from: 0);
      }
    }
  }

  List<Map<String, dynamic>> get _ticketNotifications =>
      _notifications
          .where((n) => (n['type'] ?? '').toString().contains('ticket'))
          .toList();

  void _enterSelectionMode() => setState(() {
    _selectionMode = true;
    _selectedNotificationIds.clear();
  });

  void _exitSelectionMode() => setState(() {
    _selectionMode = false;
    _selectedNotificationIds.clear();
  });

  void _toggleSelectNotification(int id) => setState(() {
    _selectedNotificationIds.contains(id)
        ? _selectedNotificationIds.remove(id)
        : _selectedNotificationIds.add(id);
  });

  Future<void> _deleteSelectedNotifications() async {
    for (final id in _selectedNotificationIds.toList()) {
      await NotificationService.deleteCustomerNotification(id);
    }
    await Provider.of<NotificationProvider>(context, listen: false).refresh();
    await _loadNotifications();
    _exitSelectionMode();
  }

  Future<void> _markAsRead(int notificationId) async {
    final index = _notifications.indexWhere((n) => n['id'] == notificationId);
    if (index == -1) return;

    final isRead = _notifications[index]['isRead'] ?? false;
    setState(() => _notifications[index]['isRead'] = !isRead);

    if (!isRead) {
      await NotificationService.markCustomerNotificationRead(notificationId);
    } else {
      await NotificationService.markCustomerNotificationUnread(notificationId);
    }

    await Provider.of<NotificationProvider>(context, listen: false).refresh();
    await _loadNotifications();
  }

  String _getTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final notificationsToShow =
        _showOnlyTickets ? _ticketNotifications : _notifications;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _surfaceSubtle,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child:
                    _isLoading
                        ? const Center(
                          child: CircularProgressIndicator(color: _primary),
                        )
                        : notificationsToShow.isEmpty
                        ? _buildEmpty()
                        : _buildList(notificationsToShow),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFEB1E23), Color(0xFF760F12)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
            child: Row(
              children: [
                if (_selectionMode)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: _exitSelectionMode,
                  )
                else
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _selectionMode
                        ? (_selectedNotificationIds.isEmpty
                            ? 'Select'
                            : '${_selectedNotificationIds.length} selected')
                        : 'Notifications',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (_selectionMode) ...[
                  if (_selectedNotificationIds.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.mark_email_read_outlined,
                        color: Colors.white,
                      ),
                      onPressed: () async {
                        for (final id in _selectedNotificationIds) {
                          await NotificationService.markCustomerNotificationRead(
                            id,
                          );
                        }
                        await Provider.of<NotificationProvider>(
                          context,
                          listen: false,
                        ).refresh();
                        await _loadNotifications();
                        _exitSelectionMode();
                      },
                      tooltip: 'Mark as read',
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white),
                    onPressed: _deleteSelectedNotifications,
                    tooltip: 'Delete',
                  ),
                ] else if (_notifications.isNotEmpty)
                  IconButton(
                    icon: const Icon(
                      Icons.checklist_outlined,
                      color: Colors.white,
                    ),
                    onPressed: _enterSelectionMode,
                    tooltip: 'Select',
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _filterChip(
                  'All',
                  !_showOnlyTickets,
                  () => setState(() => _showOnlyTickets = false),
                ),
                const SizedBox(width: 8),
                _filterChip(
                  'Tickets',
                  _showOnlyTickets,
                  () => setState(() => _showOnlyTickets = true),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _filterChip(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? Colors.white : Colors.white.withOpacity(0.3),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? _primary : Colors.white,
            ),
          ),
        ),
      );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.notifications_off_outlined,
            size: 36,
            color: _primary,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _userId == null
              ? 'Unable to determine the current admin user.'
              : "You're all caught up!",
          style: const TextStyle(fontSize: 14, color: _inkSecondary),
        ),
      ],
    ),
  );

  Widget _buildList(
    List<Map<String, dynamic>> notifications,
  ) => RefreshIndicator(
    color: _primary,
    onRefresh: _loadNotifications,
    child: AnimatedBuilder(
      animation: _animController,
      builder:
          (_, child) => Opacity(
            opacity: _animController.value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - _animController.value)),
              child: child,
            ),
          ),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final n = notifications[index];
          final id = n['id'] as int;
          final isRead = n['isRead'] ?? false;
          final color = n['color'] as Color;
          final timestamp = n['timestamp'] as DateTime;

          return Dismissible(
            key: Key('admin_notification_$id'),
            direction:
                _selectionMode
                    ? DismissDirection.none
                    : DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.white,
                size: 24,
              ),
            ),
            onDismissed:
                _selectionMode
                    ? null
                    : (_) async {
                      await NotificationService.deleteCustomerNotification(id);
                      await Provider.of<NotificationProvider>(
                        context,
                        listen: false,
                      ).refresh();
                      await _loadNotifications();
                    },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isRead ? _border : color.withOpacity(0.4),
                  width: isRead ? 1 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: isRead ? 4 : 8,
                    color: Colors.black.withOpacity(isRead ? .02 : .05),
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                onTap:
                    _selectionMode
                        ? () => _toggleSelectNotification(id)
                        : () => _markAsRead(id),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectionMode)
                        Padding(
                          padding: const EdgeInsets.only(right: 10, top: 2),
                          child: Checkbox(
                            value: _selectedNotificationIds.contains(id),
                            activeColor: _primary,
                            onChanged: (_) => _toggleSelectNotification(id),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          n['iconData'] as IconData,
                          color: color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    (n['title'] ?? 'Notification').toString(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight:
                                          isRead
                                              ? FontWeight.w500
                                              : FontWeight.w700,
                                      color: isRead ? _inkSecondary : _ink,
                                    ),
                                  ),
                                ),
                                Text(
                                  _getTimeAgo(timestamp),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _inkTertiary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (n['message'] ?? '').toString(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: _inkSecondary,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat(
                                'MMM d, yyyy • h:mm a',
                              ).format(timestamp),
                              style: const TextStyle(
                                fontSize: 11,
                                color: _inkTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_selectionMode && !isRead)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 4),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
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
