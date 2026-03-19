import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/notification_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/notification_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _ink = Color(0xFF1A1A1A);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF7F7F7);
const _border = Color(0xFFEAEAEA);

Color hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

IconData iconFromString(String iconName) {
  switch (iconName) {
    case 'check_circle':
      return Icons.check_circle_rounded;
    case 'task_alt':
      return Icons.task_alt_rounded;
    case 'cancel':
      return Icons.cancel_rounded;
    case 'confirmation_number':
      return Icons.confirmation_number_rounded;
    default:
      return Icons.notifications_rounded;
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];
  bool _selectionMode = false;
  Set<int> _selectedNotificationIds = {};

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _loadNotifications();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId == null) throw Exception('User not logged in');
      final notifications = await NotificationService.getCustomerNotifications(
        userId,
      );
      setState(() {
        _notifications =
            notifications.map((n) {
              DateTime? parsedTimestamp;
              if (n['created_at'] != null) {
                try {
                  parsedTimestamp = DateTime.parse(n['created_at'].toString());
                } catch (_) {}
              }
              return {
                ...n,
                'isRead': n['isRead'] ?? n['is_read'] == 1,
                'color': hexToColor(n['color']),
                'timestamp': parsedTimestamp,
              };
            }).toList();
        _isLoading = false;
        _selectedNotificationIds.clear();
        _selectionMode = false;
      });
      _fadeController.forward(from: 0);
    } catch (e) {
      setState(() {
        _notifications = [];
        _isLoading = false;
        _selectedNotificationIds.clear();
        _selectionMode = false;
      });
    }
  }

  void _enterSelectionMode() {
    HapticFeedback.selectionClick();
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
    HapticFeedback.selectionClick();
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
    final index = _notifications.indexWhere((n) => n['id'] == notificationId);
    if (index == -1) return;
    final isCurrentlyRead = _notifications[index]['isRead'] ?? false;
    setState(() => _notifications[index]['isRead'] = !isCurrentlyRead);
    try {
      if (!isCurrentlyRead) {
        await NotificationService.markCustomerNotificationRead(notificationId);
      } else {
        await NotificationService.markCustomerNotificationUnread(
          notificationId,
        );
      }
      await Provider.of<NotificationProvider>(context, listen: false).refresh();
    } catch (_) {
      setState(() => _notifications[index]['isRead'] = isCurrentlyRead);
      _showSnack('Failed to update notification status.', isError: true);
    }
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_sweep_rounded,
                      color: Colors.red,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Clear All Notifications',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Are you sure you want to remove all notifications? This cannot be undone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: _inkSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            backgroundColor: _surfaceSubtle,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: _inkSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            for (final n in _notifications) {
                              await NotificationService.deleteNotification(
                                n['id'],
                              );
                            }
                            await Provider.of<NotificationProvider>(
                              context,
                              listen: false,
                            ).refresh();
                            await _loadNotifications();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Clear All',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor:
            isError ? Colors.red.shade700 : const Color(0xFF24A148),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getTimeAgo(DateTime? timestamp) {
    if (timestamp == null) return 'Unknown';
    final diff = DateTime.now().difference(timestamp);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  // ── Notification tile ──────────────────────────────────────────────────────

  Widget _buildNotificationTile(Map<String, dynamic> notification, int index) {
    final id = notification['id'] as int;
    final isRead = notification['isRead'] ?? false;
    final color = notification['color'] as Color;
    final isSelected = _selectedNotificationIds.contains(id);

    return Dismissible(
      key: Key(id.toString()),
      direction:
          _selectionMode ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.delete_rounded, color: Colors.white, size: 22),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
                      content: Text('${notification['title']} removed'),
                      backgroundColor: _ink,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                      action: SnackBarAction(
                        label: 'Undo',
                        textColor: _primary,
                        onPressed: () async {
                          await NotificationService.createNotification(
                            title: deletedNotification['title'],
                            message: deletedNotification['message'],
                            type: deletedNotification['type'],
                            iconName: deletedNotification['icon'],
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
      child: GestureDetector(
        onLongPress: !_selectionMode ? _enterSelectionMode : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? _primary.withOpacity(0.05)
                    : isRead
                    ? _surfaceSubtle
                    : _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  isSelected
                      ? _primary.withOpacity(0.4)
                      : isRead
                      ? _border
                      : color.withOpacity(0.25),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow:
                isRead || isSelected
                    ? []
                    : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
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
                  // Selection checkbox or icon
                  if (_selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 10, top: 2),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? _primary : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? _primary : _border,
                            width: 1.5,
                          ),
                        ),
                        child:
                            isSelected
                                ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 14,
                                )
                                : null,
                      ),
                    )
                  else
                    // Notification icon
                    Container(
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(isRead ? 0.06 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        iconFromString(notification['icon']),
                        color: isRead ? color.withOpacity(0.5) : color,
                        size: 22,
                      ),
                    ),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                notification['title'],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      isRead
                                          ? FontWeight.w500
                                          : FontWeight.w800,
                                  color: isRead ? _inkSecondary : _ink,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getTimeAgo(notification['timestamp']),
                              style: const TextStyle(
                                fontSize: 11,
                                color: _inkTertiary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification['message'],
                          style: TextStyle(
                            fontSize: 13,
                            color: isRead ? _inkTertiary : _inkSecondary,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Unread dot
                  if (!_selectionMode && !isRead)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 8, top: 4),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final unreadCount =
        _notifications.where((n) => !(n['isRead'] ?? false)).length;
    final allSelected =
        _selectedNotificationIds.length == _notifications.length &&
        _notifications.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _surfaceSubtle,
        body: Column(
          children: [
            // ── AppBar ────────────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEB1E23), Color(0xFF9B1215)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      if (_selectionMode)
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _exitSelectionMode,
                        )
                      else
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      Expanded(
                        child:
                            _selectionMode
                                ? Text(
                                  _selectedNotificationIds.isEmpty
                                      ? 'Select'
                                      : '${_selectedNotificationIds.length} selected',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                )
                                : Row(
                                  children: [
                                    const Text(
                                      'Notifications',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    if (unreadCount > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.25),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          '$unreadCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                      ),
                      // Actions
                      if (_selectionMode) ...[
                        if (_notifications.isNotEmpty)
                          TextButton(
                            onPressed: () => _toggleSelectAll(!allSelected),
                            child: Text(
                              allSelected ? 'Deselect All' : 'Select All',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed:
                              _selectedNotificationIds.isNotEmpty
                                  ? _deleteSelectedNotifications
                                  : null,
                        ),
                      ] else ...[
                        if (_notifications.isNotEmpty)
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            color: _surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            onSelected: (val) {
                              if (val == 'select') _enterSelectionMode();
                              if (val == 'clear') _showClearAllDialog();
                            },
                            itemBuilder:
                                (_) => [
                                  const PopupMenuItem(
                                    value: 'select',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.checklist_rounded,
                                          size: 18,
                                          color: _ink,
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Select',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: _ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'clear',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_sweep_rounded,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Clear All',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(color: _primary),
                      )
                      : _notifications.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: _border,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.notifications_off_outlined,
                                size: 36,
                                color: _inkTertiary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'No notifications',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              "You're all caught up!",
                              style: TextStyle(
                                fontSize: 13,
                                color: _inkTertiary,
                              ),
                            ),
                          ],
                        ),
                      )
                      : FadeTransition(
                        opacity: _fadeAnimation,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          itemCount: _notifications.length,
                          itemBuilder:
                              (ctx, i) =>
                                  _buildNotificationTile(_notifications[i], i),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
