import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:starlink_app/features/billing/billing_actions_button.dart';
import 'package:starlink_app/core/utils/list_export.dart';
import 'package:starlink_app/core/utils/subscription_export.dart';
import 'package:starlink_app/core/utils/ticket_export.dart';
import 'package:starlink_app/shared/widgets/whats_new_dialog.dart';
import 'package:starlink_app/shared/widgets/notifications.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/features/customer/ticket/customer_ticket.dart';
import 'package:starlink_app/features/customer/ticket/customer_view.dart';
import 'package:starlink_app/features/customer/profile/customer_profile.dart';
import 'package:starlink_app/features/customer/billing/customer_billing_page.dart';
import 'package:starlink_app/features/customer/subscription/customer_subscription_page.dart';
// import 'package:provider/provider.dart'; // notifications disabled
// import 'package:starlink_app/providers/notification_provider.dart'; // notifications disabled
import 'package:flutter_svg/flutter_svg.dart';
import 'package:starlink_app/shared/widgets/modern_nav.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFF133341);
const _primaryDark = Color(0xFF0C2029);
const _header = Color(0xFF133341);
const _headerLight = Color(0xFF1E4A5E);
const _inProgress = Color(0xFF3B82F6);
const _success = Color(0xFF10B981);
const _warning = Color(0xFFF59E0B);
const _ink = Color(0xFF111111);
const _inkSecondary = Color(0xFF666666);
const _inkTertiary = Color(0xFF888888);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF8F8F8);
const _border = Color(0xFFD7D7D7);

enum CustomerQuickActionType { tickets, subscriptions, billing }

class CustomerHomeScreen extends StatefulWidget {
  final String loginMessage;

  const CustomerHomeScreen({super.key, required this.loginMessage});

  @override
  _CustomerHomeScreenState createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _selectedIndex = 0;
  final _ticketExport = ListExportController();
  final _subscriptionExport = ListExportController();
  final _billingActions = BillingListController();
  CustomerQuickActionType? _quickAction;
  bool _quickMenuOpen = false;

  OverlayEntry? _overlayEntry;

  String? _userName;
  String? _userFirstName;
  String? _userEmail;
  String? _userRole;
  String? _userPosition;
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
    // "What's new": unseen announcements, once after sign-in.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => WhatsNew.maybeShow(context),
    );
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Notifications disabled: the backend has no /v1/notifications route.
      // Provider.of<NotificationProvider>(context, listen: false).refresh();
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  // ── Supplemental data fetcher ──────────────────────────────────────────

  http.Client get _httpClient {
    final httpClient =
        HttpClient()
          ..connectionTimeout = const Duration(seconds: 15);
    return IOClient(httpClient);
  }

  Future<void> _loadUserData() async {
    try {
      // 1. Fetch from basic endpoint
      final profileResponse = await ApiService.getMe();

      if (profileResponse['status'] != 'success' ||
          profileResponse['data'] == null) {
        throw Exception(
          profileResponse['message'] ?? 'Failed to fetch user profile',
        );
      }

      final Map<String, dynamic> merged = Map<String, dynamic>.from(
        profileResponse['data'] as Map<String, dynamic>,
      );

      // 2. Fetch from supplemental profile endpoint (contains position)
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
        debugPrint('[CustomerHome] Supplemental profile data error: $e');
      }

      final userData = merged;
      debugPrint('[CustomerHome] Merged userData: $userData');

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
        _userPosition =
            userData['position']?.toString() ??
            userData['role']?.toString() ??
            userData['job_title']?.toString() ??
            'Customer';
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

      // Backend scopes /subscriptions/paginated to the caller's own records;
      // the /customer/:id and /end-user/:id routes are staff-only (403).
      response = await ApiService.getSubscriptionsPaginated(limit: 100);

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
          (_) => ModernQuickMenu<CustomerQuickActionType>(
            items: const [
              QuickMenuItem(
                value: CustomerQuickActionType.tickets,
                icon: Icons.confirmation_number_outlined,
                label: 'Tickets',
                subtitle: 'Create and track support tickets',
                color: _warning,
              ),
              QuickMenuItem(
                value: CustomerQuickActionType.subscriptions,
                icon: Icons.subscriptions_outlined,
                label: 'Subscriptions',
                subtitle: 'View your service lines',
                color: Color(0xFF133341),
              ),
              QuickMenuItem(
                value: CustomerQuickActionType.billing,
                icon: Icons.receipt_long_outlined,
                label: 'Billing',
                subtitle: 'Invoices and payments',
                color: _success,
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
        return 'Tickets';
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
      backgroundColor: _header,
      surfaceTintColor: _header,
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
        child: Container(height: 3, color: _headerLight),
      ),
      actions: [
        if (_selectedIndex == 1 &&
            _quickAction == CustomerQuickActionType.tickets)
          ExportTicketsButton(controller: _ticketExport),
        if (_selectedIndex == 1 &&
            _quickAction == CustomerQuickActionType.subscriptions)
          ExportSubscriptionsButton(controller: _subscriptionExport),
        if (_selectedIndex == 1 &&
            _quickAction == CustomerQuickActionType.billing)
          BillingActionsButton(controller: _billingActions),
        const Padding(
          padding: EdgeInsets.only(right: 6),
          child: NotificationBell(),
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
      return CustomerTicketScreen(
        showAppBar: false,
        exportController: _ticketExport,
      );
    } else if (_quickAction == CustomerQuickActionType.subscriptions) {
      return CustomerSubscriptionPage(
        showAppBar: false,
        exportController: _subscriptionExport,
      );
    } else if (_quickAction == CustomerQuickActionType.billing) {
      return CustomerBillingPage(
        showAppBar: false,
        actionsController: _billingActions,
      );
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
    final userData =
        {}; // In a real app we might store the raw map, let's keep it simple as we have the variables.
    final position = _userPosition ?? 'Customer';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_header, _headerLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _header.withOpacity(0.30),
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
          Container(
            width: 18,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: const TextStyle(
              color: _header,
              fontSize: 22,
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
    return ModernNavBar(
      children: [
        ModernNavItem(
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
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
        ModernCenterButton(
          open: _quickMenuOpen,
          onTap: () => _onNavTap(1),
          child:
              _quickAction != null
                  ? Icon(
                    _quickActionIcon(_quickAction),
                    color: Colors.white,
                    size: 24,
                  )
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

// ── Reusable widgets ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Row(
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
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: _header,
          letterSpacing: 1.1,
        ),
      ),
    ],
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
