import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../components/notification_badge.dart';
import '../../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ticket/customer_ticket_screen.dart';
import '../ticket/customer_ticket.dart';
import '../ticket/customer_view.dart';
import '../profile/customer_profile.dart';
import '../profile/customer_notification.dart';
import '../ticket/customer_ticket_modal.dart';
import '../billing/customer_billing_page.dart';
import '../subscription/customer_subscription_page.dart';
import '../subscription/customer_subscription_detail_page.dart';
import 'package:provider/provider.dart';
import '../../../providers/notification_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

enum CustomerQuickActionType { tickets, subscriptions, billing }

class CustomerHomeScreen extends StatefulWidget {
  final String loginMessage;

  const CustomerHomeScreen({super.key, required this.loginMessage});

  @override
  _CustomerHomeScreenState createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _selectedIndex = 0;
  CustomerQuickActionType? _quickAction;
  bool _quickMenuOpen = false;

  OverlayEntry? _overlayEntry;

  String? _userName;
  String? _userFirstName;
  String? _userEmail;
  String? _userRole;
  bool _isLoading = true;
  int? _userId;

  String? _euCode;
  String? _customerCode;

  List<Map<String, dynamic>> _subscriptions = [];

  int _openCount = 0;
  int _inProgressCount = 0;
  int _resolvedCount = 0;
  int _closedCount = 0;

  List<dynamic> _recentActivity = const [];
  bool _loadingTickets = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).refresh();
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final profileResponse = await ApiService.getMe();

      if (profileResponse['status'] != 'success' ||
          profileResponse['data'] == null) {
        throw Exception(
          profileResponse['message'] ?? 'Failed to fetch user profile',
        );
      }

      final userData = profileResponse['data'] as Map<String, dynamic>;

      final idRaw = userData['id'];
      final int? parsedId =
          idRaw is int ? idRaw : int.tryParse(idRaw?.toString() ?? '');

      final euCode =
          userData['eu_code']?.toString() ??
          userData['euCode']?.toString() ??
          userData['company']?.toString();
      final customerCode =
          userData['customer_code']?.toString() ??
          userData['com_eu_code']?.toString() ??
          userData['customerCode']?.toString() ??
          userData['company']?.toString();

      setState(() {
        _userId = parsedId;
        _euCode = euCode;
        _customerCode = customerCode;
        _userName =
            userData['name']?.toString() ??
            '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'
                .trim();
        _userFirstName = userData['first_name']?.toString() ?? _userName;
        _userEmail = userData['email']?.toString();
        _userRole = userData['role']?.toString();
        _isLoading = false;
      });

      final prefs = await SharedPreferences.getInstance();
      if (_userId != null) await prefs.setInt('user_id', _userId!);
      await prefs.setString('name', _userName ?? '');
      await prefs.setString('first_name', _userFirstName ?? '');
      await prefs.setString('email', _userEmail ?? '');
      await prefs.setString('role', _userRole ?? '');
      if (euCode != null) await prefs.setString('eu_code', euCode);
      if (customerCode != null) {
        await prefs.setString('customer_code', customerCode);
      }
      await prefs.setString('userProfile', json.encode(userData));

      await Future.wait([_loadSubscriptions(), _loadTicketStats()]);
    } catch (e) {
      debugPrint('[CustomerHome] _loadUserData error: $e');
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userId = prefs.getInt('user_id');
        _userName = prefs.getString('name');
        _userFirstName = prefs.getString('first_name');
        _userEmail = prefs.getString('email');
        _userRole = prefs.getString('role');
        _euCode = prefs.getString('eu_code');
        _customerCode = prefs.getString('customer_code');
        _isLoading = false;
      });
      await Future.wait([_loadSubscriptions(), _loadTicketStats()]);
    }
  }

  Future<void> _loadTicketStats() async {
    setState(() => _loadingTickets = true);
    try {
      final results = await Future.wait([
        ApiService.getMyOpenTickets(),
        ApiService.getMyInProgressTickets(),
        ApiService.getMyResolvedTickets(),
        ApiService.getMyClosedTickets(),
        ApiService.getRecentTicketActivity(),
      ]);

      int? tryParseInt(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString());
      }

      int countFromData(dynamic data) {
        if (data is num) return data.toInt();
        if (data is List) return data.length;
        if (data is Map) {
          for (final k in const [
            'count',
            'total',
            'totalCount',
            'total_count',
            'total_items',
          ]) {
            final parsed = tryParseInt(data[k]);
            if (parsed != null) return parsed;
          }
          for (final k in const [
            'data',
            'items',
            'tickets',
            'rows',
            'results',
            'list',
          ]) {
            final v = data[k];
            if (v is num) return v.toInt();
            if (v is List) return v.length;
          }
        }
        return 0;
      }

      int countFromResponse(dynamic res) {
        if (res is Map && res['status'] == 'success') {
          final fromData = countFromData(res['data']);
          if (fromData > 0) return fromData;
          final fromRaw = countFromData(res['raw']);
          if (fromRaw > 0) return fromRaw;
        }
        return 0;
      }

      List<dynamic> listFromResponse(dynamic res) {
        if (res is Map && res['status'] == 'success') {
          final candidates = [res['data'], res['raw']];
          for (final c in candidates) {
            if (c is List) return c;
            if (c is Map) {
              for (final k in const [
                'activity',
                'activities',
                'recent',
                'events',
                'data',
                'items',
                'rows',
                'results',
                'list',
              ]) {
                final v = c[k];
                if (v is List) return v;
              }
            }
          }
        }
        return const [];
      }

      if (mounted) {
        setState(() {
          _openCount = countFromResponse(results[0]);
          _inProgressCount = countFromResponse(results[1]);
          _resolvedCount = countFromResponse(results[2]);
          _closedCount = countFromResponse(results[3]);
          _recentActivity = listFromResponse(results[4]);
          _loadingTickets = false;
        });
      }
    } catch (e) {
      debugPrint('[CustomerHome] _loadTicketStats error: $e');
      if (mounted) setState(() => _loadingTickets = false);
    }
  }

  Future<void> _loadSubscriptions() async {
    try {
      Map<String, dynamic>? response;

      if (_euCode != null && _euCode!.isNotEmpty) {
        response = await ApiService.getSubscriptionsByEndUserId(_euCode!);
      } else if (_customerCode != null && _customerCode!.isNotEmpty) {
        response = await ApiService.getSubscriptionsByCustomerId(
          _customerCode!,
        );
      } else {
        final token = await ApiService.getValidAccessToken();
        if (token != null) {
          final raw = await ApiService.getSubscriptions(bearerToken: token);
          response = {'status': 'success', 'data': raw};
        }
      }

      if (response != null &&
          response['status'] == 'success' &&
          response['data'] != null) {
        final List<dynamic> rawList =
            response['data'] is List ? response['data'] : [];
        final subscriptions =
            rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        setState(() => _subscriptions = subscriptions);
      }
    } catch (e) {
      debugPrint('[CustomerHome] _loadSubscriptions error: $e');
    }
  }

  // ── Overlay ────────────────────────────────────────────────────────────────

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _toggleQuickMenu() {
    if (_quickMenuOpen) {
      _closeQuickMenu();
    } else {
      _openQuickMenu();
    }
  }

  void _openQuickMenu() {
    setState(() => _quickMenuOpen = true);
    _overlayEntry = OverlayEntry(
      builder:
          (_) => _QuickMenuOverlay(
            quickMenuOpen: _quickMenuOpen,
            activeAction: _quickAction,
            onDismiss: _closeQuickMenu,
            onSelect: _selectQuickAction,
          ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeQuickMenu() {
    _removeOverlay();
    if (mounted) {
      setState(() {
        _quickMenuOpen = false;
        if (_selectedIndex == 1 && _quickAction == null) {
          _selectedIndex = 0;
        }
      });
    }
  }

  void _onNavTap(int index) {
    if (index == 1) {
      _toggleQuickMenu();
      return;
    }
    _closeQuickMenu();
    setState(() => _selectedIndex = index == 0 ? 0 : 2);
  }

  void _selectQuickAction(CustomerQuickActionType type) {
    _closeQuickMenu();
    setState(() {
      _quickAction = type;
      _selectedIndex = 1;
    });
  }

  // ── Navigate to ticket detail ──────────────────────────────────────────────

  void _openTicketDetail(dynamic activity) {
    // Build a ticket map that CustomerViewScreen expects
    final a =
        activity is Map
            ? Map<String, dynamic>.from(activity)
            : <String, dynamic>{};

    final id = (a['id'] ?? a['ticket_id'] ?? '').toString().trim();
    if (id.isEmpty) return;

    final subject =
        (a['subject'] ?? a['title'] ?? a['ticket_type'] ?? '')
            .toString()
            .trim();
    final status =
        (a['status'] ?? a['ticket_status'] ?? 'open').toString().trim();
    final createdBy =
        (a['created_by'] ?? a['createdBy'] ?? '').toString().trim();
    final createdAt =
        (a['created_at'] ?? a['createdAt'] ?? '').toString().trim();

    final ticket = <String, dynamic>{
      'id': id,
      'subject': subject.isNotEmpty ? subject : 'Ticket #$id',
      'status': status,
      'created_by': createdBy,
      'created_at': createdAt,
      'full_data': a,
    };

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CustomerViewScreen(ticket: ticket)),
    );
  }

  // ── Misc helpers ───────────────────────────────────────────────────────────

  String _getAppBarTitle() {
    if (_selectedIndex == 0) return 'Dashboard';
    if (_selectedIndex == 2) return 'Profile';
    switch (_quickAction) {
      case CustomerQuickActionType.tickets:
        return 'My Tickets';
      case CustomerQuickActionType.subscriptions:
        return 'Subscriptions';
      case CustomerQuickActionType.billing:
        return 'Billing';
      default:
        return 'Quick Actions';
    }
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.trim()[0].toUpperCase();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _surfaceSubtle,
      appBar: _buildAppBar(),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : _buildBodyContent(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
        if (_selectedIndex == 0)
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
                        builder: (_) => const CustomerNotificationScreen(),
                      ),
                    ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBodyContent() {
    if (_selectedIndex == 0) return _buildDashboard();
    if (_selectedIndex == 2) {
      return const CustomerProfileScreen(showAppBar: false);
    }

    if (_quickAction == CustomerQuickActionType.tickets) {
      return const CustomerTicketScreen(showAppBar: false);
    } else if (_quickAction == CustomerQuickActionType.subscriptions) {
      return const CustomerSubscriptionPage(showAppBar: false);
    } else if (_quickAction == CustomerQuickActionType.billing) {
      return const CustomerBillingPage(showAppBar: false);
    } else {
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
              'Tap the center button to open\nTickets, Subscriptions, or Billing.',
              style: TextStyle(color: _inkSecondary, fontSize: 13, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _loadUserData,
      color: _primary,
      strokeWidth: 2,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildWelcomeCard(),
                const SizedBox(height: 20),
                _buildTicketOverviewCard(),
                const SizedBox(height: 20),
                // ── MY SUBSCRIPTIONS section hidden ────────────────────
                // Uncomment to re-enable:
                // _buildSubscriptionsSection(),
                // const SizedBox(height: 20),
                // ──────────────────────────────────────────────────────
                _buildRecentActivitySection(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Welcome Card ───────────────────────────────────────────────────────────

  Widget _buildWelcomeCard() {
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
                    _initials(_userFirstName ?? _userName),
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
                      _userFirstName ?? _userName ?? 'User',
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
                  (_userRole ?? 'Customer').toUpperCase(),
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
                              builder:
                                  (_) => const CustomerNotificationScreen(),
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

  // ── Ticket Overview ────────────────────────────────────────────────────────

  Widget _buildTicketOverviewCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'MY TICKETS'),
        const SizedBox(height: 12),
        Row(
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
                Icons.check_circle,
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
      ],
    );
  }

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

  // ── Subscriptions (hidden) ─────────────────────────────────────────────────

  Widget _buildSubscriptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'MY SUBSCRIPTIONS'),
        const SizedBox(height: 12),
        if (_subscriptions.isEmpty)
          const _EmptyState(
            icon: Icons.subscriptions_outlined,
            message: 'No subscriptions found.',
          )
        else
          ...List.generate(_subscriptions.length, (i) {
            final sub = _subscriptions[i];
            final rawActive =
                sub['active'] ??
                sub['status'] ??
                sub['is_active'] ??
                sub['isActive'];
            final isActive =
                rawActive == true ||
                rawActive == 1 ||
                rawActive?.toString().toLowerCase() == 'true' ||
                rawActive?.toString().toLowerCase() == 'active' ||
                rawActive?.toString().toLowerCase() == 'enabled' ||
                rawActive?.toString() == '1';
            final nickname =
                (sub['nickname'] ?? sub['name'] ?? '').toString().trim();
            final serviceLineNumber =
                (sub['serviceLineNumber'] ?? sub['service_line_number'] ?? '')
                    .toString()
                    .trim();
            final endDate =
                (sub['endDate'] ?? sub['end_date'] ?? sub['expires_at'] ?? '')
                    .toString()
                    .trim();
            return Padding(
              padding: EdgeInsets.only(
                bottom: i == _subscriptions.length - 1 ? 0 : 10,
              ),
              child: _SubscriptionTile(
                nickname: nickname.isNotEmpty ? nickname : serviceLineNumber,
                serviceLineNumber:
                    serviceLineNumber.isEmpty ? '—' : serviceLineNumber,
                endDate: endDate.isEmpty ? '—' : endDate,
                active: isActive ? 'Active' : 'Inactive',
                isActive: isActive,
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => CustomerSubscriptionDetailsPage(
                              serviceLineNumber: serviceLineNumber,
                              title:
                                  nickname.isNotEmpty
                                      ? nickname
                                      : (serviceLineNumber.isNotEmpty
                                          ? serviceLineNumber
                                          : 'Subscription'),
                            ),
                      ),
                    ),
              ),
            );
          }),
      ],
    );
  }

  // ── Recent Activity ────────────────────────────────────────────────────────

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'RECENT ACTIVITY'),
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
          ...List.generate(_recentActivity.take(5).length, (i) {
            final a = _recentActivity[i];

            final id = (a['id'] ?? a['ticket_id'] ?? '').toString().trim();
            final createdBy =
                (a['created_by'] ?? a['createdBy'] ?? '').toString().trim();
            final createdAt = _formatDate(
              (a['created_at'] ?? a['createdAt'] ?? a['timestamp'] ?? '')
                  .toString()
                  .trim(),
            );
            final subject =
                (a['subject'] ?? a['title'] ?? a['ticket_type'] ?? '')
                    .toString()
                    .trim();
            final status =
                (a['status'] ?? a['ticket_status'] ?? '').toString().trim();
            final color = _statusColor(status);

            return Padding(
              padding: EdgeInsets.only(
                bottom: i == _recentActivity.take(5).length - 1 ? 0 : 10,
              ),
              child: _ActivityTile(
                title: id.isNotEmpty ? 'Ticket #$id' : 'Ticket',
                subtitle: [
                  if (subject.isNotEmpty) subject,
                  if (createdBy.isNotEmpty) 'By: $createdBy',
                  if (createdAt.isNotEmpty && createdAt != '—') createdAt,
                ].join(' · '),
                status: status.isNotEmpty ? status : '—',
                statusColor: color,
                // ── FIX: pass onTap to open ticket detail ───────────────
                onTap: id.isNotEmpty ? () => _openTicketDetail(a) : null,
              ),
            );
          }),
      ],
    );
  }

  String _formatDate(String raw) {
    if (raw.isEmpty || raw == '—') return '—';
    try {
      final dt = DateTime.parse(raw);
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
      return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
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

  // ── Bottom Nav ─────────────────────────────────────────────────────────────

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
            selected: _selectedIndex == 0,
            onTap: () {
              _closeQuickMenu();
              setState(() {
                _selectedIndex = 0;
                _quickAction = null; // ← reset to logo
              });
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
                  child:
                      _quickMenuOpen
                          ? Icon(Icons.close, color: _primary, size: 24)
                          : (_quickAction != null
                              ? Icon(
                                _quickActionIcon(_quickAction),
                                color: Colors.white,
                                size: 24,
                              )
                              : Center(
                                child: SvgPicture.asset(
                                  'assets/images/logo.svg',
                                  width: 18,
                                  height: 18,
                                  fit: BoxFit.contain,
                                  colorFilter: const ColorFilter.mode(
                                    Colors.white,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              )),
                ),
              ),
            ),
          ),
          _NavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            selected: _selectedIndex == 2,
            onTap: () {
              _closeQuickMenu();
              setState(() {
                _selectedIndex = 2;
                _quickAction = null; // ← reset to logo
              });
            },
          ),
        ],
      ),
    );
  }

  IconData _quickActionIcon(CustomerQuickActionType? type) {
    switch (type) {
      case CustomerQuickActionType.tickets:
        return Icons.confirmation_number_outlined;
      case CustomerQuickActionType.subscriptions:
        return Icons.subscriptions_outlined;
      case CustomerQuickActionType.billing:
        return Icons.receipt_long_outlined;
      default:
        return Icons.flash_on_outlined;
    }
  }
}

// ── Quick Menu Overlay ─────────────────────────────────────────────────────────

class _QuickMenuOverlay extends StatefulWidget {
  final bool quickMenuOpen;
  final CustomerQuickActionType? activeAction;
  final VoidCallback onDismiss;
  final ValueChanged<CustomerQuickActionType> onSelect;

  const _QuickMenuOverlay({
    required this.quickMenuOpen,
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
    final screenWidth = mq.size.width;
    final screenHeight = mq.size.height;
    final bottomInset = mq.padding.bottom;
    const navBarContentHeight = 60.0;
    final navBarHeight =
        navBarContentHeight + (bottomInset > 0 ? bottomInset : 10);
    final fabCenterX = screenWidth / 2;
    final fabCenterY = screenHeight - navBarHeight / 2 - 12;

    const bubbleSize = 56.0;
    const labelHeight = 20.0;
    const gap = 6.0;
    const totalH = bubbleSize + gap + labelHeight;

    final actions = [
      _BubbleSpec(
        type: CustomerQuickActionType.tickets,
        icon: Icons.confirmation_number_outlined,
        label: 'Ticket',
        color: _warning,
        dx: -76.0,
        dy: -78.0,
        delay: 0.0,
      ),
      _BubbleSpec(
        type: CustomerQuickActionType.subscriptions,
        icon: Icons.subscriptions_outlined,
        label: 'Subs',
        color: _primary,
        dx: 0.0,
        dy: -118.0,
        delay: 0.07,
      ),
      _BubbleSpec(
        type: CustomerQuickActionType.billing,
        icon: Icons.receipt_long_outlined,
        label: 'Billing',
        color: _success,
        dx: 76.0,
        dy: -78.0,
        delay: 0.14,
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
              final cx = fabCenterX + spec.dx * t;
              final cy = fabCenterY + spec.dy * t;
              final left = cx - bubbleSize / 2;
              final top = cy - bubbleSize / 2;
              return Positioned(
                left: left,
                top: top,
                width: bubbleSize,
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
                    width: bubbleSize,
                    height: bubbleSize,
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
                              : Colors.white.withOpacity(0.85),
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
  final CustomerQuickActionType type;
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

// ── Reusable widgets ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: _inkTertiary,
      letterSpacing: 1.1,
    ),
  );
}

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

class _SubscriptionTile extends StatelessWidget {
  final String nickname;
  final String serviceLineNumber;
  final String endDate;
  final String active;
  final bool isActive;
  final VoidCallback? onTap;

  const _SubscriptionTile({
    required this.nickname,
    required this.serviceLineNumber,
    required this.endDate,
    required this.active,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _success : _primaryDark;
    final icon = isActive ? Icons.check_circle_outline : Icons.cancel_outlined;

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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      serviceLineNumber,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _inkSecondary,
                      ),
                    ),
                    Text(
                      'Expires: $endDate',
                      style: const TextStyle(fontSize: 11, color: _inkTertiary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      active,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _inkTertiary,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
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
              // ── Chevron shown when tappable ─────────────────────────
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
