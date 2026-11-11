import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:starlink_app/core/utils/list_export.dart';
import 'package:starlink_app/core/utils/subscription_export.dart';
import 'package:starlink_app/core/utils/ticket_export.dart';
import 'package:starlink_app/shared/widgets/whats_new_dialog.dart';
import 'package:starlink_app/shared/widgets/notifications.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:starlink_app/shared/widgets/modern_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:provider/provider.dart'; // notifications disabled
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:starlink_app/features/end_user/ticket/ticket_screen.dart'
    show TicketScreen, EndUserTicketDetailsScreen;
import 'package:starlink_app/features/end_user/profile/profile_screen.dart';
import 'package:starlink_app/services/api_service.dart';
// import 'package:starlink_app/providers/notification_provider.dart'; // notifications disabled
// import 'package:starlink_app/features/end_user/home/subscription_header.dart';
// import 'package:starlink_app/features/end_user/home/billing_cycle_chart.dart';
import 'package:starlink_app/features/end_user/subscription/end_user_subscription_page.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFF133341);
const _primaryDark = Color(0xFF0C2029);
const _inProgress = Color(0xFF3B82F6);
const _success = Color(0xFF10B981);
const _warning = Color(0xFFF59E0B);
const _ink = Color(0xFF111111);
const _inkSecondary = Color(0xFF666666);
const _inkTertiary = Color(0xFF888888);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF8F8F8);
const _border = Color(0xFFD7D7D7);

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
  final _ticketExport = ListExportController();
  final _subscriptionExport = ListExportController();
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
    // "What's new": unseen announcements, once after sign-in.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => WhatsNew.maybeShow(context),
    );
    _loadAll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Notifications disabled: the backend has no /v1/notifications route.
      // Provider.of<NotificationProvider>(context, listen: false).refresh();
      if (widget.loginMessage != null) {
        AppToast.success(context, widget.loginMessage!);
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

  // ── Helper ───────────────────────────────────────────────────────────────

  http.Client get _httpClient {
    final httpClient =
        HttpClient()
          ..connectionTimeout = const Duration(seconds: 15);
    return IOClient(httpClient);
  }

  // ── Profile load (for welcome card only) ──────────────────────────────────

  Future<void> _loadUserProfile() async {
    try {
      // 1. Fetch from basic endpoint
      final meRes = await ApiService.getCurrentUserProfile();
      Map<String, dynamic> merged = {};
      if (meRes['status'] == 'success' && meRes['data'] != null) {
        merged.addAll(Map<String, dynamic>.from(meRes['data'] as Map));
      }

      // 2. Fetch from profile endpoint (contains position)
      try {
        final token = await ApiService.getValidAccessToken();
        if (token != null && token.isNotEmpty) {
          final uri = Uri.parse('${ApiService.baseUrl}/v1/users/my/profile/');
          final res = await _httpClient
              .get(
                uri,
                headers: {
                  'Accept': 'application/json',
                  'Authorization': 'Bearer $token',
                },
              )
              .timeout(const Duration(seconds: 15));

          if (res.statusCode == 200) {
            final decoded = json.decode(res.body);
            if (decoded is Map<String, dynamic>) {
              final extraData =
                  (decoded['data'] as Map<String, dynamic>?) ?? decoded;
              merged.addAll(extraData);
            }
          }
        }
      } catch (e) {
        debugPrint('[HomeScreen] Supplemental profile data error: $e');
      }

      if (merged.isNotEmpty) {
        if (mounted) setState(() => _userProfile = merged);
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userProfile', json.encode(merged));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[HomeScreen] _loadUserProfile error: $e');
      // Fallback to SharedPreferences if API fails
      try {
        final prefs = await SharedPreferences.getInstance();
        final profileStr = prefs.getString('userProfile');
        if (profileStr != null) {
          setState(
            () =>
                _userProfile = Map<String, dynamic>.from(
                  json.decode(profileStr),
                ),
          );
        }
      } catch (_) {}
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
          (_) => ModernQuickMenu<_QuickActionType>(
            items: const [
              QuickMenuItem(
                value: _QuickActionType.tickets,
                icon: Icons.confirmation_number_outlined,
                label: 'Tickets',
                subtitle: 'Create and track support tickets',
                color: _warning,
              ),
              QuickMenuItem(
                value: _QuickActionType.subscriptions,
                icon: Icons.subscriptions_outlined,
                label: 'Subscriptions',
                subtitle: 'View your service lines',
                color: Color(0xFF133341),
              ),
            ],
            active: _quickAction,
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
        return 'Tickets';
      case _QuickActionType.subscriptions:
        return 'Subscriptions';
      default:
        return 'Quick Actions';
    }
  }

  IconData _quickActionIcon() {
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
    final profile = _userProfile ?? {};
    final position =
        profile['position']?.toString() ??
        profile['job_title']?.toString() ??
        'User';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF133341), Color(0xFF0C2029)],
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
      child: Row(
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
          const SizedBox(width: 8),
          // Long positions are cut off so the greeting keeps its width.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 112),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                position.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
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
        return TicketScreen(exportController: _ticketExport);
      case _QuickActionType.subscriptions:
        return UserSubscriptionPage(exportController: _subscriptionExport);
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
    return ModernNavBar(
      children: [
        ModernNavItem(
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
          label: 'Dashboard',
          selected: _currentIndex == 0,
          onTap: () {
            _closeQuickMenu();
            setState(() {
              _currentIndex = 0;
              _quickAction = null;
            });
          },
        ),
        ModernCenterButton(
          open: _quickMenuOpen,
          onTap: () => _onNavTap(1),
          child:
              _quickAction != null
                  ? Icon(_quickActionIcon(), color: Colors.white, size: 24)
                  : SvgPicture.asset(
                    'assets/images/logo.svg',
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
        ),
        ModernNavItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person_rounded,
          label: 'Profile',
          selected: _currentIndex == 2,
          onTap: () {
            _closeQuickMenu();
            setState(() {
              _currentIndex = 2;
              _quickAction = null;
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceSubtle,
      appBar: AppBar(
        backgroundColor: const Color(0xFF133341),
        surfaceTintColor: const Color(0xFF133341),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(height: 3, color: const Color(0xFF1E4A5E)),
        ),
        actions: [
          if (_currentIndex == 1 && _quickAction == _QuickActionType.tickets)
            ExportTicketsButton(controller: _ticketExport),
          if (_currentIndex == 1 &&
              _quickAction == _QuickActionType.subscriptions)
            ExportSubscriptionsButton(controller: _subscriptionExport),
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: NotificationBell(),
          ),
        ],
        // actions: [
        //   if (_currentIndex == 0)
        //     Padding(
        //       padding: const EdgeInsets.only(right: 8),
        //       child: NotificationBadge(
        //         badgeColor: _primary,
        //         textColor: Colors.white,
        //         badgeSize: 18,
        //         fontSize: 9,
        //         child: IconButton(
        //           icon: const Icon(
        //             Icons.notifications_outlined,
        //             color: _ink,
        //             size: 22,
        //           ),
        //           onPressed:
        //               () => Navigator.push(
        //                 context,
        //                 MaterialPageRoute(
        //                   builder: (_) => const NotificationsPage(),
        //                 ),
        //               ),
        //         ),
        //       ),
        //     ),
        // ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}

// ── Quick Menu Overlay ─────────────────────────────────────────────────────────

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
