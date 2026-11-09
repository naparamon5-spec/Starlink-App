import 'package:flutter/material.dart';
import 'package:starlink_app/features/ticket/ticket_details_view.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/services/push_service.dart';

// The signed-in user's own notifications: ticket events, usage alerts and
// announcements (GET /v1/notifications and friends).

const _pageSize = 20;

const _primary = Color(0xFF133341);
const _ink = Color(0xFF0F172A);
const _inkSecondary = Color(0xFF64748B);
const _inkTertiary = Color(0xFF94A3B8);
const _surfaceSubtle = Color(0xFFF8F8F8);

int? _idOf(Map<String, dynamic> a) => int.tryParse('${a['id']}');

bool _isUnread(Map<String, dynamic> a) => a['read_at'] == null;

/// The ticket a notification is about, if any.
String? _ticketIdOf(Map<String, dynamic> a) {
  final data = a['data'];
  final id = data is Map ? data['ticket_id'] : null;
  return id?.toString();
}

({IconData icon, Color color, String label}) _typeStyle(String? type) {
  const blue = Color(0xFF3B82F6);
  const green = Color(0xFF10B981);
  const amber = Color(0xFFF59E0B);
  switch (type) {
    case 'ticket_created':
      return (
        icon: Icons.confirmation_number_rounded,
        color: blue,
        label: 'New ticket',
      );
    case 'ticket_reply':
      return (
        icon: Icons.chat_bubble_rounded,
        color: blue,
        label: 'Ticket reply',
      );
    case 'ticket_accepted':
      return (
        icon: Icons.check_circle_rounded,
        color: green,
        label: 'Ticket accepted',
      );
    case 'ticket_resolved':
      return (
        icon: Icons.task_alt_rounded,
        color: green,
        label: 'Ticket resolved',
      );
    case 'ticket_closed':
      return (
        icon: Icons.lock_rounded,
        color: _inkSecondary,
        label: 'Ticket closed',
      );
    case 'usage_alert':
      return (
        icon: Icons.data_usage_rounded,
        color: amber,
        label: 'Usage alert',
      );
    case 'announcement':
      return (
        icon: Icons.campaign_rounded,
        color: _primary,
        label: 'Announcement',
      );
    default:
      return (
        icon: Icons.notifications_rounded,
        color: _primary,
        label: 'Notice',
      );
  }
}

String _timeAgo(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final dt = DateTime.tryParse(raw)?.toLocal();
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

/// Bell for the app bar, with an unread count badge. Opens [NotificationsPage].
class NotificationBell extends StatefulWidget {
  final Color color;

  const NotificationBell({super.key, this.color = Colors.white});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    PushService.foregroundMessages.addListener(_loadCount);
    _loadCount();
  }

  @override
  void dispose() {
    PushService.foregroundMessages.removeListener(_loadCount);
    super.dispose();
  }

  Future<void> _loadCount() async {
    final res = await ApiService.getNotificationUnreadCount();
    if (!mounted || res['status'] != 'success') return;
    final data = res['data'];
    final count = data is Map ? int.tryParse('${data['count']}') : null;
    if (count != null) setState(() => _unread = count);
  }

  Future<void> _open() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
    _loadCount();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: _open,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            _unread > 0
                ? Icons.notifications_rounded
                : Icons.notifications_none_rounded,
            color: widget.color,
            size: 24,
          ),
          if (_unread > 0)
            Positioned(
              right: -5,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17),
                height: 17,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE90408),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: _primary, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    _unread > 9 ? '9+' : '$_unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lists the signed-in user's notifications, newest first.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _unread = 0;
  String? _error;
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    final results = await Future.wait([
      ApiService.getNotifications(limit: _pageSize),
      ApiService.getNotificationUnreadCount(),
    ]);
    if (!mounted) return;
    final res = results[0];
    final count = results[1]['data'];
    setState(() {
      _loading = false;
      if (res['status'] == 'success') {
        _items = (res['data'] as List).cast<Map<String, dynamic>>();
        _hasMore = _items.length == _pageSize;
        _unread =
            (count is Map ? int.tryParse('${count['count']}') : null) ??
            _items.where(_isUnread).length;
      } else {
        _error = res['message']?.toString() ?? 'Could not load notifications.';
      }
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _items.isEmpty) return;
    setState(() => _loadingMore = true);
    final res = await ApiService.getNotifications(
      before: _idOf(_items.last),
      limit: _pageSize,
    );
    if (!mounted) return;
    setState(() {
      _loadingMore = false;
      if (res['status'] == 'success') {
        final more = (res['data'] as List).cast<Map<String, dynamic>>();
        _items.addAll(more);
        _hasMore = more.length == _pageSize;
      }
    });
  }

  void _markRead(Map<String, dynamic> a) {
    final id = _idOf(a);
    if (id == null || !_isUnread(a)) return;
    setState(() {
      a['read_at'] = DateTime.now().toIso8601String();
      if (_unread > 0) _unread--;
    });
    ApiService.markNotificationRead(id);
  }

  void _markAllRead() {
    final now = DateTime.now().toIso8601String();
    setState(() {
      for (final a in _items.where(_isUnread)) {
        a['read_at'] = now;
      }
      _unread = 0;
    });
    ApiService.markAllNotificationsRead();
  }

  void _open(Map<String, dynamic> a) {
    _markRead(a);
    final ticketId = _ticketIdOf(a);
    if (ticketId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TicketDetailsView(ticketId: ticketId)),
      );
      return;
    }
    final id = _idOf(a);
    if (id == null) return;
    setState(() {
      if (!_expanded.remove(id)) _expanded.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceSubtle,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (_unread > 0)
            IconButton(
              tooltip: 'Mark all as read',
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all_rounded),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: _load,
        child: _buildBody(_unread),
      ),
    );
  }

  Widget _buildBody(int unreadCount) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_error != null) {
      return _message(
        Icons.cloud_off_rounded,
        'Something went wrong',
        _error!,
        isError: true,
      );
    }
    if (_items.isEmpty) {
      return _message(
        Icons.notifications_off_outlined,
        "You're all caught up",
        'Ticket updates, usage alerts and announcements will show up here.',
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                unreadCount > 0 ? '$unreadCount UNREAD' : 'ALL CAUGHT UP',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _primary,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        for (final a in _items) _tile(a),
        if (_hasMore)
          Center(
            child:
                _loadingMore
                    ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(color: _primary),
                    )
                    : TextButton(
                      onPressed: _loadMore,
                      child: const Text('Load more'),
                    ),
          ),
      ],
    );
  }

  Widget _message(
    IconData icon,
    String title,
    String body, {
    bool isError = false,
  }) {
    final accent = isError ? const Color(0xFFE90408) : _primary;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 32),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isError ? accent : _ink,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isError ? accent : _inkSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile(Map<String, dynamic> a) {
    final style = _typeStyle(a['type']?.toString());
    final unread = _isUnread(a);
    final expanded = _expanded.contains(_idOf(a));
    final title = (a['title'] ?? '').toString();
    final body = (a['body'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _open(a),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    unread
                        ? _primary.withOpacity(0.25)
                        : const Color(0xFFEDF1F5),
              ),
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: style.color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(style.icon, color: style.color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            style.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: style.color,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _timeAgo(a['created_at']?.toString()),
                            style: const TextStyle(
                              fontSize: 11,
                              color: _inkTertiary,
                            ),
                          ),
                          if (unread) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE90408),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              unread ? FontWeight.w800 : FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          body,
                          maxLines: expanded ? null : 2,
                          overflow:
                              expanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: _inkSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
