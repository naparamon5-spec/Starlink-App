import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../ticket/ticket_screen.dart'
    show TicketScreen, EndUserTicketDetailsScreen;
import '../profile/profile_screen.dart';
import '../profile/notifications.dart';
import '../../../services/api_service.dart';
import '../../../components/notification_badge.dart';
import '../../../providers/notification_provider.dart';
// import 'subscription_header.dart';
// import 'billing_cycle_chart.dart';
import '../subscription/end_user_subscription_page.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _inProgress = Color(0xFF0F62FE);
const _success = Color(0xFF24A148);
const _warning = Color(0xFFFF832B);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);
const _danger = Color(0xFFE57373);

enum _QuickActionType { tickets, subscriptions }

class HomeScreen extends StatefulWidget {
  final String? loginMessage;
  final int userId;

  const HomeScreen({super.key, this.loginMessage, required this.userId});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  _QuickActionType? _quickAction;
  bool _quickMenuOpen = false;
  OverlayEntry? _overlayEntry;

  bool _isLoading = true;

  // ── Subscription data kept in state but not displayed ─────────────────────
  // Uncomment the relevant UI sections below to re-enable subscription display.
  // Map<String, dynamic>? _subscriptionData;
  // List<Map<String, dynamic>> _billingCycles = [];

  String? _errorMessage;
  Map<String, dynamic>? _userProfile;

  int _openCount = 0;
  int _inProgressCount = 0;
  int _resolvedCount = 0;
  int _closedCount = 0;
  bool _loadingTickets = true;

  List<dynamic> _recentActivity = const [];

  // Expiring subscriptions kept but not displayed.
  // List<dynamic> _expiringSubscriptions = const [];

  @override
  void initState() {
    super.initState();
    _loadAll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).refresh();
      if (widget.loginMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.loginMessage!)),
              ],
            ),
            backgroundColor: _success,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _loadingTickets = true;
      _errorMessage = null;
    });
    // Load profile for welcome card + ticket stats.
    // Subscription loading is commented out.
    await Future.wait([_loadUserProfile(), _loadTicketStats()]);
    if (mounted) setState(() => _isLoading = false);
  }

  // ── Response helpers ──────────────────────────────────────────────────────

  List<dynamic>? _digList(dynamic v) {
    if (v is List) return v;
    if (v is Map) {
      for (final k in const [
        'data',
        'items',
        'rows',
        'results',
        'list',
        'tickets',
        'activity',
        'activities',
        'subscriptions',
        'recent',
        'events',
      ]) {
        final inner = v[k];
        if (inner is List) return inner;
      }
    }
    return null;
  }

  List<dynamic> _extractList(Map<String, dynamic> res) {
    if (res['status'] != 'success') return [];
    return _digList(res['data']) ?? _digList(res['raw']) ?? [];
  }

  int _extractCount(Map<String, dynamic> res) {
    if (res['status'] != 'success') return 0;
    int? toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    int? fromMap(dynamic m) {
      if (m is! Map) return null;
      for (final k in const [
        'count',
        'total',
        'totalCount',
        'total_count',
        'total_items',
        'totalItems',
      ]) {
        final r = toInt(m[k]);
        if (r != null) return r;
      }
      final pag = m['pagination'];
      if (pag is Map) {
        for (final k in const ['total', 'totalCount', 'total_count', 'count']) {
          final r = toInt(pag[k]);
          if (r != null) return r;
        }
      }
      final list = _digList(m);
      if (list != null) return list.length;
      return null;
    }

    final d = res['data'];
    final direct = toInt(d);
    if (direct != null) return direct;
    if (d is List) return d.length;
    final fromData = fromMap(d);
    if (fromData != null) return fromData;
    return fromMap(res['raw']) ?? 0;
  }

  // ── Profile load (for welcome card only) ──────────────────────────────────

  Future<void> _loadUserProfile() async {
    try {
      final meRes = await ApiService.getCurrentUserProfile();
      if (meRes['status'] == 'success' && meRes['data'] != null) {
        final user = Map<String, dynamic>.from(meRes['data'] as Map);
        if (mounted) setState(() => _userProfile = user);
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userProfile', json.encode(user));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[HomeScreen] _loadUserProfile error: $e');
    }
  }

  // ── Subscription data load — kept for future use, not called ─────────────
  //
  // Future<void> _loadSubscriptionData() async { ... }
  // Future<void> _loadBillingCycles() async { ... }

  // ── Ticket stats ──────────────────────────────────────────────────────────

  Future<void> _loadTicketStats() async {
    if (mounted) setState(() => _loadingTickets = true);
    try {
      final results = await Future.wait([
        ApiService.getMyOpenTickets(),
        ApiService.getMyInProgressTickets(),
        ApiService.getMyResolvedTickets(),
        ApiService.getMyClosedTickets(),
        ApiService.getRecentTicketActivity(),
        // Expiring subs call kept but result unused:
        // ApiService.getExpiringSubscriptionsList(),
      ]);
      if (mounted) {
        setState(() {
          _openCount = _extractCount(results[0]);
          _inProgressCount = _extractCount(results[1]);
          _resolvedCount = _extractCount(results[2]);
          _closedCount = _extractCount(results[3]);
          _recentActivity = _extractList(results[4]);
          // _expiringSubscriptions = _extractList(results[5]);
          _loadingTickets = false;
        });
      }
    } catch (e) {
      debugPrint('[HomeScreen] _loadTicketStats error: $e');
      if (mounted) setState(() => _loadingTickets = false);
    }
  }

  // ── Overlay helpers ───────────────────────────────────────────────────────

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _toggleQuickMenu() =>
      _quickMenuOpen ? _closeQuickMenu() : _openQuickMenu();

  void _openQuickMenu() {
    setState(() => _quickMenuOpen = true);
    _overlayEntry = OverlayEntry(
      builder:
          (_) => _QuickMenuOverlay(
            activeAction: _quickAction,
            onDismiss: _closeQuickMenu,
            onSelect: _selectQuickAction,
          ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeQuickMenu() {
    _removeOverlay();
    if (mounted) setState(() => _quickMenuOpen = false);
  }

  void _selectQuickAction(_QuickActionType type) {
    _closeQuickMenu();
    setState(() {
      _quickAction = type;
      _currentIndex = 1;
    });
  }

  void _onNavTap(int index) {
    if (index == 1) {
      _toggleQuickMenu();
      return;
    }
    _closeQuickMenu();
    setState(() => _currentIndex = index == 0 ? 0 : 2);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _getAppBarTitle() {
    if (_currentIndex == 0) return 'Dashboard';
    if (_currentIndex == 2) return 'Profile';
    switch (_quickAction) {
      case _QuickActionType.tickets:
        return 'My Tickets';
      case _QuickActionType.subscriptions:
        return 'Subscriptions';
      default:
        return 'Quick Actions';
    }
  }

  IconData _fabIcon() {
    if (_quickMenuOpen) return Icons.close;
    switch (_quickAction) {
      case _QuickActionType.tickets:
        return Icons.confirmation_number_outlined;
      case _QuickActionType.subscriptions:
        return Icons.subscriptions_outlined;
      default:
        return Icons.flash_on_outlined;
    }
  }

  String _formatDate(String raw) {
    if (raw.isEmpty || raw == '—') return '—';
    try {
      final dt = DateTime.parse(
        raw.contains('T') ? raw : raw.replaceFirst(' ', 'T'),
      );
      const m = [
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
      return '${m[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  Color _statusColor(String s) {
    final v = s.toLowerCase();
    if (v.contains('open')) return _warning;
    if (v.contains('progress')) return _inProgress;
    if (v.contains('resolved')) return _success;
    if (v.contains('closed')) return const Color(0xFFA8A8A8);
    return _inkTertiary;
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.trim()[0].toUpperCase();
  }

  String _displayName() {
    if (_userProfile == null) return 'User';
    final name = _userProfile!['name']?.toString();
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final fn = _userProfile!['first_name']?.toString() ?? '';
    final ln = _userProfile!['last_name']?.toString() ?? '';
    final full = '$fn $ln'.trim();
    return full.isNotEmpty ? full : 'User';
  }

  String _firstName() {
    if (_userProfile == null) return 'User';
    final fn = _userProfile!['first_name']?.toString();
    if (fn != null && fn.trim().isNotEmpty) return fn.trim();
    return _displayName().split(' ').first;
  }

  // ── Home content ──────────────────────────────────────────────────────────

  Widget _buildHomeContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_primary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: _primary,
      strokeWidth: 2,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Welcome Card ──────────────────────────────────────────
                _buildWelcomeCard(),
                const SizedBox(height: 20),

                // ── My Tickets ────────────────────────────────────────────
                _buildSectionHeader('MY TICKETS'),
                const SizedBox(height: 12),
                _loadingTickets
                    ? Row(
                      children: List.generate(
                        4,
                        (_) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _skeletonCard(),
                          ),
                        ),
                      ),
                    )
                    : Row(
                      children: [
                        Expanded(
                          child: _ticketCard(
                            'Open',
                            _openCount,
                            _warning,
                            Icons.error_outline,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ticketCard(
                            'In Progress',
                            _inProgressCount,
                            _inProgress,
                            Icons.sync,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ticketCard(
                            'Resolved',
                            _resolvedCount,
                            _success,
                            Icons.check_circle_outline,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ticketCard(
                            'Closed',
                            _closedCount,
                            const Color(0xFFA8A8A8),
                            Icons.lock_outline,
                          ),
                        ),
                      ],
                    ),
                const SizedBox(height: 20),

                // ── MY SUBSCRIPTION — hidden ───────────────────────────────
                // Uncomment to re-enable:
                // if (_subscriptionData != null) ...[
                //   _buildSectionHeader('MY SUBSCRIPTION'),
                //   const SizedBox(height: 12),
                //   Container(
                //     decoration: BoxDecoration(
                //       color: _surface,
                //       borderRadius: BorderRadius.circular(16),
                //       border: Border.all(color: _border),
                //       boxShadow: [BoxShadow(
                //         color: Colors.black.withOpacity(0.03),
                //         blurRadius: 8, offset: const Offset(0, 2),
                //       )],
                //     ),
                //     padding: const EdgeInsets.all(16),
                //     child: SubscriptionHeader(
                //       subscriptionData: _subscriptionData!,
                //       billingCycle: _billingCycles.isNotEmpty
                //           ? _billingCycles.first : null,
                //     ),
                //   ),
                //   const SizedBox(height: 20),
                // ],

                // ── EXPIRING SOON — hidden ─────────────────────────────────
                // Uncomment to re-enable:
                // if (_expiringSubscriptions.isNotEmpty) ...[
                //   _buildSectionHeader('EXPIRING SOON'),
                //   const SizedBox(height: 12),
                //   ..._expiringSubscriptions.take(3).map((sub) { ... }),
                //   const SizedBox(height: 8),
                // ],

                // ── BILLING HISTORY — hidden ───────────────────────────────
                // Uncomment to re-enable:
                // _buildSectionHeader('BILLING HISTORY'),
                // const SizedBox(height: 12),
                // Container(
                //   decoration: BoxDecoration(
                //     color: _surface,
                //     borderRadius: BorderRadius.circular(16),
                //     border: Border.all(color: _border),
                //     boxShadow: [BoxShadow(
                //       color: Colors.black.withOpacity(0.03),
                //       blurRadius: 8, offset: const Offset(0, 2),
                //     )],
                //   ),
                //   padding: const EdgeInsets.all(16),
                //   child: BillingCycleChart(billingCycles: _billingCycles),
                // ),
                // const SizedBox(height: 20),

                // ── Recent Activity ───────────────────────────────────────
                _buildSectionHeader('RECENT ACTIVITY'),
                const SizedBox(height: 12),
                if (_loadingTickets) ...[
                  const _SkeletonTile(),
                  const SizedBox(height: 10),
                  const _SkeletonTile(),
                ] else if (_recentActivity.isEmpty)
                  const _EmptyState(
                    icon: Icons.history_outlined,
                    message: 'No recent activity.',
                  )
                else
                  ...List.generate(math.min(_recentActivity.length, 5), (i) {
                    final raw = _recentActivity[i];
                    final a =
                        raw is Map
                            ? Map<String, dynamic>.from(raw)
                            : <String, dynamic>{};

                    final id =
                        (a['id'] ?? a['ticket_id'] ?? '').toString().trim();
                    final createdBy =
                        (a['created_by'] ?? a['createdBy'] ?? '')
                            .toString()
                            .trim();
                    final createdAt = _formatDate(
                      (a['created_at'] ??
                              a['createdAt'] ??
                              a['timestamp'] ??
                              '')
                          .toString()
                          .trim(),
                    );
                    final subject =
                        (a['subject'] ?? a['title'] ?? a['ticket_type'] ?? '')
                            .toString()
                            .trim();
                    final status =
                        (a['status'] ?? a['ticket_status'] ?? '')
                            .toString()
                            .trim();
                    final color = _statusColor(status);

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom:
                            i == math.min(_recentActivity.length, 5) - 1
                                ? 0
                                : 10,
                      ),
                      child: _ActivityTile(
                        title: id.isNotEmpty ? 'Ticket #$id' : 'Ticket',
                        subtitle: [
                          if (subject.isNotEmpty) subject,
                          if (createdBy.isNotEmpty) 'By: $createdBy',
                          if (createdAt.isNotEmpty && createdAt != '—')
                            createdAt,
                        ].join(' · '),
                        status: status.isNotEmpty ? status : '—',
                        statusColor: color,
                        onTap:
                            id.isNotEmpty
                                ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => EndUserTicketDetailsScreen(
                                          ticketId: id,
                                          ticket: {
                                            'id': id,
                                            'type':
                                                subject.isNotEmpty
                                                    ? subject
                                                    : 'Ticket',
                                            'status':
                                                status.isNotEmpty
                                                    ? status
                                                    : 'OPEN',
                                            'description': '',
                                            'contact': createdBy,
                                            'subscription': '',
                                            'created_at':
                                                a['created_at']?.toString() ??
                                                '',
                                            'full_data':
                                                Map<String, dynamic>.from(a),
                                          },
                                        ),
                                  ),
                                )
                                : null,
                      ),
                    );
                  }),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Welcome Card ──────────────────────────────────────────────────────────

  Widget _buildWelcomeCard() {
    final name = _displayName();
    final first = _firstName();
    final role = _userProfile?['role']?.toString() ?? 'User';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEB1E23), Color(0xFF760F12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryDark.withOpacity(0.38),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.75),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      first,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              final count = provider.unreadCount;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        count == 0
                            ? 'No new notifications'
                            : 'You have $count new notification${count == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationsPage(),
                            ),
                          ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'View All',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: _inkTertiary,
      letterSpacing: 1.1,
    ),
  );

  // ── Ticket card ────────────────────────────────────────────────────────────

  Widget _ticketCard(String title, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(height: 10),
          Text(
            '$count',
            style: const TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(
              color: _inkSecondary,
              fontSize: 10,
              height: 1.1,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _skeletonCard() => Container(
    height: 84,
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _surfaceSubtle,
            borderRadius: BorderRadius.circular(7),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 12,
          width: 28,
          decoration: BoxDecoration(
            color: _surfaceSubtle,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    ),
  );

  // ── Body / nav ─────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_currentIndex == 0) return _buildHomeContent();
    if (_currentIndex == 2) return const ProfileScreen();
    switch (_quickAction) {
      case _QuickActionType.tickets:
        return const TicketScreen();
      case _QuickActionType.subscriptions:
        return const UserSubscriptionPage();
      default:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flash_on_outlined,
                  color: _primary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tap the centre button to open\nTickets or Subscriptions.',
                style: TextStyle(
                  color: _inkSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
    }
  }

  Widget _buildBottomNav() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: const Border(top: BorderSide(color: _border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: bottomInset > 0 ? bottomInset : 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            selected: _currentIndex == 0,
            onTap: () {
              _closeQuickMenu();
              setState(() => _currentIndex = 0);
            },
          ),
          GestureDetector(
            onTap: () => _onNavTap(1),
            child: Transform.translate(
              offset: const Offset(0, -12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _quickMenuOpen ? _surfaceSubtle : _primary,
                  shape: BoxShape.circle,
                  border:
                      _quickMenuOpen
                          ? Border.all(color: _primary, width: 2)
                          : null,
                  boxShadow: [
                    BoxShadow(
                      color: _primaryDark.withOpacity(
                        _quickMenuOpen ? 0.15 : 0.40,
                      ),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: AnimatedRotation(
                  turns: _quickMenuOpen ? 0.125 : 0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Icon(
                    _fabIcon(),
                    color: _quickMenuOpen ? _primary : Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          _NavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            selected: _currentIndex == 2,
            onTap: () {
              _closeQuickMenu();
              setState(() => _currentIndex = 2);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceSubtle,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            color: _ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
        actions: [
          if (_currentIndex == 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: NotificationBadge(
                badgeColor: _primary,
                textColor: Colors.white,
                badgeSize: 18,
                fontSize: 9,
                child: IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: _ink,
                    size: 22,
                  ),
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsPage(),
                        ),
                      ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}

// ── Quick Menu Overlay ─────────────────────────────────────────────────────────

class _QuickMenuOverlay extends StatefulWidget {
  final _QuickActionType? activeAction;
  final VoidCallback onDismiss;
  final ValueChanged<_QuickActionType> onSelect;

  const _QuickMenuOverlay({
    required this.activeAction,
    required this.onDismiss,
    required this.onSelect,
  });

  @override
  State<_QuickMenuOverlay> createState() => _QuickMenuOverlayState();
}

class _QuickMenuOverlayState extends State<_QuickMenuOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final sw = mq.size.width;
    final sh = mq.size.height;
    final bi = mq.padding.bottom;
    const navH = 60.0;
    final totalNavH = navH + (bi > 0 ? bi : 10);
    final fcx = sw / 2;
    final fcy = sh - totalNavH / 2 - 12;
    const bs = 56.0;
    const lh = 20.0;
    const gap = 6.0;
    const totalH = bs + gap + lh;

    final actions = [
      _BubbleSpec(
        type: _QuickActionType.tickets,
        icon: Icons.confirmation_number_outlined,
        label: 'Ticket',
        color: _warning,
        dx: -52.0,
        dy: -90.0,
        delay: 0.0,
      ),
      _BubbleSpec(
        type: _QuickActionType.subscriptions,
        icon: Icons.subscriptions_outlined,
        label: 'Subs',
        color: _primary,
        dx: 52.0,
        dy: -90.0,
        delay: 0.07,
      ),
    ];

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: AnimatedBuilder(
              animation: _controller,
              builder:
                  (_, __) => Container(
                    color: Colors.black.withOpacity(0.55 * _controller.value),
                  ),
            ),
          ),
        ),
        ...actions.map((spec) {
          final anim = CurvedAnimation(
            parent: _controller,
            curve: Interval(
              spec.delay,
              math.min(spec.delay + 0.65, 1.0),
              curve: Curves.elasticOut,
            ),
          );
          return AnimatedBuilder(
            animation: anim,
            builder: (_, child) {
              final t = anim.value.clamp(0.0, 1.0);
              return Positioned(
                left: fcx + spec.dx * t - bs / 2,
                top: fcy + spec.dy * t - bs / 2,
                width: bs,
                height: totalH,
                child: Opacity(
                  opacity: t,
                  child: Transform.scale(
                    scale: t,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                ),
              );
            },
            child: GestureDetector(
              onTap: () => widget.onSelect(spec.type),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: bs,
                    height: bs,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          widget.activeAction == spec.type
                              ? spec.color
                              : _surface,
                      border: Border.all(
                        color: spec.color.withOpacity(0.5),
                        width: widget.activeAction == spec.type ? 0 : 1.5,
                      ),
                    ),
                    child: Icon(
                      spec.icon,
                      color:
                          widget.activeAction == spec.type
                              ? Colors.white
                              : spec.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: gap),
                  Text(
                    spec.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          widget.activeAction == spec.type
                              ? spec.color
                              : Colors.white.withOpacity(0.9),
                      letterSpacing: 0.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _BubbleSpec {
  final _QuickActionType type;
  final IconData icon;
  final String label;
  final Color color;
  final double dx, dy, delay;

  const _BubbleSpec({
    required this.type,
    required this.icon,
    required this.label,
    required this.color,
    required this.dx,
    required this.dy,
    required this.delay,
  });
}

// ── Reusable small widgets ────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, color: _inkTertiary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _inkSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final VoidCallback? onTap;

  const _ActivityTile({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.history_toggle_off_outlined,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: _inkTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _inkTertiary,
                  size: 16,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _surfaceSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 11,
                  width: 150,
                  decoration: BoxDecoration(
                    color: _surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 9,
                  width: 100,
                  decoration: BoxDecoration(
                    color: _surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? _primary : _inkTertiary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
