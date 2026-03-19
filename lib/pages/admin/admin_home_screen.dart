import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../services/api_service.dart';
import 'sections/ticket/admin_tickets_page.dart';
import 'sections/ticket/admin_ticket_details_page.dart';
import 'sections/ticket/admin_create_ticket_page.dart';
import 'sections/agent/admin_agents_page.dart';
import 'sections/billing/admin_billing_page.dart';
import 'sections/subscription/admin_subscriptions_page.dart';
import 'sections/subscription/admin_subscription_details_page.dart';
import 'sections/enduser/admin_end_users_page.dart';
import 'profile/admin_edit_profile_page.dart';
import 'profile/admin_manage_users_page.dart';
import 'profile/admin_user_guide_page.dart';
import 'sections/agent/admin_create_agent_page.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _primaryBright = Color(0xFFEA0509);
const _inProgress = Color(0xFF0F62FE);
const _success = Color(0xFF24A148);
const _warning = Color(0xFFFF832B);
const _danger = Color(0xFFEB1E23);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

enum QuickActionType { tickets, subscriptions, billing }

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;
  QuickActionType? _quickAction;
  bool _quickMenuOpen = false;

  OverlayEntry? _overlayEntry;

  bool _loadingDashboard = true;
  String? _dashboardError;
  Map<String, dynamic>? _me;
  int _openCount = 0;
  int _inProgressCount = 0;
  int _resolvedCount = 0;
  int _closedCount = 0;
  List<dynamic> _recentActivity = const [];
  List<dynamic> _expiringSubscriptions = const [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  // ── Overlay helpers ───────────────────────────────────────────────────────
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _openQuickMenu() {
    setState(() => _quickMenuOpen = true);
    _overlayEntry = OverlayEntry(
      builder:
          (_) => _AdminQuickMenuOverlay(
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

  void _toggleQuickMenu() {
    if (_quickMenuOpen) {
      _closeQuickMenu();
    } else {
      _openQuickMenu();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadDashboard() async {
    setState(() {
      _loadingDashboard = true;
      _dashboardError = null;
    });

    final meRes = await ApiService.getMe();
    if (!mounted) return;

    if (meRes['status'] != 'success') {
      setState(() {
        _loadingDashboard = false;
        _dashboardError =
            meRes['message']?.toString() ?? 'Failed to load profile';
        _me = null;
      });
      return;
    }

    final meData =
        (meRes['data'] is Map<String, dynamic>)
            ? meRes['data'] as Map<String, dynamic>
            : <String, dynamic>{};

    final results = await Future.wait([
      ApiService.getMyOpenTickets(),
      ApiService.getMyInProgressTickets(),
      ApiService.getMyResolvedTickets(),
      ApiService.getMyClosedTickets(),
      ApiService.getRecentTicketActivity(),
      ApiService.getExpiringSubscriptionsList(),
    ]);

    if (!mounted) return;

    int? tryParseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    int? countFromData(dynamic data) {
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
        for (final v in data.values) {
          final nested = countFromData(v);
          if (nested != null) return nested;
        }
      }
      return null;
    }

    int countFromResponse(dynamic res) {
      if (res is Map && res['status'] == 'success') {
        final fromData = countFromData(res['data']);
        if (fromData != null) return fromData;
        final fromRaw = countFromData(res['raw']);
        if (fromRaw != null) return fromRaw;
      }
      return 0;
    }

    List<dynamic> listFromResponse(
      dynamic res, {
      List<String> preferredKeys = const [],
    }) {
      if (res is Map && res['status'] == 'success') {
        final candidates = [res['data'], res['raw']];
        for (final c in candidates) {
          if (c is List) return c;
          if (c is Map) {
            for (final k in preferredKeys) {
              final v = c[k];
              if (v is List) return v;
            }
            for (final k in const [
              'data',
              'items',
              'rows',
              'results',
              'list',
            ]) {
              final v = c[k];
              if (v is List) return v;
            }
            for (final v in c.values) {
              if (v is List) return v;
            }
          }
        }
      }
      return const [];
    }

    setState(() {
      _me = meData;
      _openCount = countFromResponse(results[0]);
      _inProgressCount = countFromResponse(results[1]);
      _resolvedCount = countFromResponse(results[2]);
      _closedCount = countFromResponse(results[3]);
      _recentActivity = listFromResponse(
        results[4],
        preferredKeys: const ['activity', 'activities', 'recent', 'events'],
      );
      _expiringSubscriptions = listFromResponse(
        results[5],
        preferredKeys: const ['subscriptions', 'expiring', 'data', 'items'],
      );
      _loadingDashboard = false;
      final anyError = results.whereType<Map>().any(
        (r) => r['status'] != 'success',
      );
      if (anyError) {
        _dashboardError =
            'Some dashboard sections failed to load. Pull to refresh.';
      }
    });
  }

  Future<void> _openCreateTicket() async {
    final token = await ApiService.getValidAccessToken();
    if (!mounted) return;
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminCreateTicketPage(bearerToken: token),
      ),
    );
    if (created == true) _loadDashboard();
  }

  Future<void> _openCreateAgent() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdminCreateAgentPage()),
    );
    if (created == true) _loadDashboard();
  }

  void _selectQuickAction(QuickActionType type) {
    _closeQuickMenu();
    setState(() {
      _selectedIndex = 2;
      _quickAction = type;
    });
  }

  void _onNavTap(int index) {
    if (index == 2) {
      _toggleQuickMenu();
      return;
    }
    _closeQuickMenu();
    setState(() => _selectedIndex = index);
  }

  List<Widget> _buildBodySlivers() {
    switch (_selectedIndex) {
      case 0:
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _QuickCreateSection(
                  onNewTicket: _openCreateTicket,
                  onNewAgent: _openCreateAgent,
                ),
                const SizedBox(height: 16),
                _TicketOverviewCard(
                  isLoading: _loadingDashboard,
                  open: _openCount,
                  inProgress: _inProgressCount,
                  resolved: _resolvedCount,
                  closed: _closedCount,
                ),
                const SizedBox(height: 16),
                _SubscriptionSection(
                  isLoading: _loadingDashboard,
                  subscriptions: _expiringSubscriptions,
                ),
                const SizedBox(height: 16),
                _RecentActivitySection(
                  isLoading: _loadingDashboard,
                  activities: _recentActivity,
                ),
              ]),
            ),
          ),
        ];
      case 1:
        return [
          const SliverFillRemaining(
            hasScrollBody: true,
            child: AdminAgentsPage(),
          ),
        ];
      case 2:
        if (_quickAction == QuickActionType.tickets) {
          return [
            const SliverFillRemaining(
              hasScrollBody: true,
              child: AdminTicketsPage(),
            ),
          ];
        } else if (_quickAction == QuickActionType.subscriptions) {
          return [
            const SliverFillRemaining(
              hasScrollBody: true,
              child: AdminSubscriptionsPage(),
            ),
          ];
        } else if (_quickAction == QuickActionType.billing) {
          return [
            const SliverFillRemaining(
              hasScrollBody: true,
              child: AdminBillingPage(),
            ),
          ];
        } else {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
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
                      'Tap the Quick Action button\nto open Tickets, Subscriptions, or Billing.',
                      style: TextStyle(
                        color: _inkSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ];
        }
      case 3:
        return [
          const SliverFillRemaining(
            hasScrollBody: true,
            child: AdminEndUsersPage(),
          ),
        ];
      case 4:
        return [
          SliverFillRemaining(
            hasScrollBody: true,
            child: _SettingsSection(me: _me),
          ),
        ];
      default:
        return const [
          SliverFillRemaining(hasScrollBody: false, child: SizedBox.shrink()),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _surfaceSubtle,
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: _onNavTap,
        quickMenuOpen: _quickMenuOpen,
        quickAction: _quickAction,
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          color: _primary,
          strokeWidth: 2,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (_selectedIndex == 0 && _dashboardError != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _danger.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _danger.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: _danger,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _dashboardError!,
                              style: const TextStyle(
                                color: _danger,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ..._buildBodySlivers(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Admin Quick Menu Overlay (full-screen, renders above bottom nav) ───────────

class _AdminQuickMenuOverlay extends StatefulWidget {
  final QuickActionType? activeAction;
  final VoidCallback onDismiss;
  final ValueChanged<QuickActionType> onSelect;

  const _AdminQuickMenuOverlay({
    required this.activeAction,
    required this.onDismiss,
    required this.onSelect,
  });

  @override
  State<_AdminQuickMenuOverlay> createState() => _AdminQuickMenuOverlayState();
}

class _AdminQuickMenuOverlayState extends State<_AdminQuickMenuOverlay>
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
    // FAB center: horizontally centered, vertically at nav bar middle, lifted 12px
    final fabCenterX = screenWidth / 2;
    final fabCenterY = screenHeight - navBarHeight / 2 - 12;

    const bubbleSize = 56.0;
    const labelHeight = 20.0;
    const gap = 6.0;
    const totalH = bubbleSize + gap + labelHeight;

    final actions = [
      _AdminBubbleSpec(
        type: QuickActionType.tickets,
        icon: Icons.confirmation_number_outlined,
        label: 'Ticket',
        color: _warning,
        dx: -76.0,
        dy: -78.0,
        delay: 0.0,
      ),
      _AdminBubbleSpec(
        type: QuickActionType.subscriptions,
        icon: Icons.subscriptions_outlined,
        label: 'Subs',
        color: _primary,
        dx: 0.0,
        dy: -118.0,
        delay: 0.07,
      ),
      _AdminBubbleSpec(
        type: QuickActionType.billing,
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
        // Dim backdrop
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
        // Bubbles
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

class _AdminBubbleSpec {
  final QuickActionType type;
  final IconData icon;
  final String label;
  final Color color;
  final double dx, dy, delay;

  const _AdminBubbleSpec({
    required this.type,
    required this.icon,
    required this.label,
    required this.color,
    required this.dx,
    required this.dy,
    required this.delay,
  });
}

// ─── Quick Create Buttons ─────────────────────────────────────────────────────

class _QuickCreateSection extends StatelessWidget {
  final VoidCallback onNewTicket;
  final VoidCallback onNewAgent;
  const _QuickCreateSection({
    required this.onNewTicket,
    required this.onNewAgent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickCreateButton(
            icon: Icons.confirmation_number_outlined,
            label: 'New Ticket',
            color: _primary,
            onTap: onNewTicket,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickCreateButton(
            icon: Icons.person_add_outlined,
            label: 'New Agent',
            color: _primaryDark,
            onTap: onNewAgent,
          ),
        ),
      ],
    );
  }
}

class _QuickCreateButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickCreateButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Ticket Overview Card ─────────────────────────────────────────────────────

class _TicketOverviewCard extends StatelessWidget {
  final bool isLoading;
  final int open, inProgress, resolved, closed;

  const _TicketOverviewCard({
    required this.isLoading,
    required this.open,
    required this.inProgress,
    required this.resolved,
    required this.closed,
  });

  @override
  Widget build(BuildContext context) {
    final total = open + inProgress + resolved + closed;
    final segments = <Widget>[
      if (open > 0) _BarSegment(flex: open, color: _warning),
      if (inProgress > 0) _BarSegment(flex: inProgress, color: _inProgress),
      if (resolved > 0) _BarSegment(flex: resolved, color: _success),
      if (closed > 0) _BarSegment(flex: closed, color: const Color(0xFFA8A8A8)),
    ];

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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.confirmation_number_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Ticket Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                isLoading ? '…' : '$total total',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child:
                segments.isEmpty
                    ? Container(
                      height: 8,
                      color: Colors.white.withOpacity(0.15),
                    )
                    : Row(children: segments),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BarLegend(color: _warning, label: 'Open', count: open),
              _BarLegend(
                color: _inProgress,
                label: 'In Progress',
                count: inProgress,
              ),
              _BarLegend(color: _success, label: 'Resolved', count: resolved),
              _BarLegend(
                color: const Color(0xFFA8A8A8),
                label: 'Closed',
                count: closed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BarSegment extends StatelessWidget {
  final int flex;
  final Color color;
  const _BarSegment({required this.flex, required this.color});

  @override
  Widget build(BuildContext context) =>
      Flexible(flex: flex, child: Container(height: 8, color: color));
}

class _BarLegend extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _BarLegend({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.65),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Subscription Section ─────────────────────────────────────────────────────

class _SubscriptionSection extends StatelessWidget {
  final bool isLoading;
  final List<dynamic> subscriptions;

  const _SubscriptionSection({
    required this.isLoading,
    required this.subscriptions,
  });

  String _nameFromSub(dynamic sub) {
    if (sub is Map) {
      final n =
          (sub['name'] ??
                  sub['customer_name'] ??
                  sub['end_user_name'] ??
                  sub['customer'] ??
                  sub['user'] ??
                  '')
              .toString();
      if (n.trim().isNotEmpty) return n.trim();
    }
    return 'Subscription';
  }

  String _nicknameFromSub(dynamic sub) {
    if (sub is Map) {
      final n = (sub['nickname'] ?? sub['name'] ?? '').toString();
      if (n.trim().isNotEmpty) return n.trim();
    }
    return '';
  }

  String _serviceLineFromSub(dynamic sub) {
    if (sub is Map) {
      final s =
          (sub['serviceLineNumber'] ??
                  sub['service_line_number'] ??
                  sub['serviceLine'] ??
                  '')
              .toString();
      if (s.trim().isNotEmpty) return s.trim();
    }
    return '';
  }

  String _endDateFromSub(dynamic sub) {
    if (sub is Map) {
      final r =
          (sub['end_date'] ??
                  sub['expires_at'] ??
                  sub['expiry_date'] ??
                  sub['endDate'] ??
                  sub['end'] ??
                  '')
              .toString();
      if (r.trim().isNotEmpty) return r.trim();
    }
    return '';
  }

  String _activeFromSub(dynamic sub) {
    if (sub is Map) {
      final a = (sub['active'] ?? sub['status'] ?? '').toString();
      if (a.trim().isNotEmpty) return a.trim();
    }
    return '';
  }

  void _openSubscriptionDetails(
    BuildContext context, {
    required String serviceLineNumber,
    required String nickname,
  }) {
    if (serviceLineNumber.trim().isEmpty || serviceLineNumber.trim() == '—') {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => AdminSubscriptionDetailsPage(
              serviceLineNumber: serviceLineNumber.trim(),
              title:
                  nickname.trim().isEmpty
                      ? serviceLineNumber.trim()
                      : nickname.trim(),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'SUBSCRIPTION END DATES'),
          SizedBox(height: 12),
          _SkeletonTile(),
          SizedBox(height: 10),
          _SkeletonTile(),
        ],
      );
    }
    final top = subscriptions.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'SUBSCRIPTION END DATES'),
        const SizedBox(height: 12),
        if (top.isEmpty)
          _EmptyState(
            icon: Icons.subscriptions_outlined,
            message: 'No expiring subscriptions found.',
          )
        else
          ...List.generate(top.length, (i) {
            final sub = top[i];
            final endDate = _endDateFromSub(sub);
            final nickname = _nicknameFromSub(sub);
            final serviceLine = _serviceLineFromSub(sub);
            final active = _activeFromSub(sub);
            final displayName =
                nickname.isNotEmpty ? nickname : _nameFromSub(sub);
            return Padding(
              padding: EdgeInsets.only(bottom: i == top.length - 1 ? 0 : 10),
              child: _SubscriptionTile(
                nickname: displayName,
                serviceLineNumber: serviceLine.isEmpty ? '—' : serviceLine,
                endDate: endDate.isEmpty ? '—' : endDate,
                active: active.isEmpty ? '—' : active,
                onTap:
                    serviceLine.trim().isEmpty
                        ? null
                        : () => _openSubscriptionDetails(
                          context,
                          serviceLineNumber: serviceLine,
                          nickname: displayName,
                        ),
              ),
            );
          }),
      ],
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

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

// ─── Empty State ──────────────────────────────────────────────────────────────

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

// ─── Recent Activity ──────────────────────────────────────────────────────────

class _RecentActivitySection extends StatelessWidget {
  final bool isLoading;
  final List<dynamic> activities;

  const _RecentActivitySection({
    required this.isLoading,
    required this.activities,
  });

  String _idFromActivity(dynamic a) {
    if (a is Map) {
      final v = (a['id'] ?? a['ticket_id'] ?? '').toString();
      if (v.trim().isNotEmpty) return v.trim();
    }
    return '—';
  }

  String _createdByFromActivity(dynamic a) {
    if (a is Map) {
      final v = (a['created_by'] ?? a['createdBy'] ?? '').toString();
      if (v.trim().isNotEmpty) return v.trim();
    }
    return '—';
  }

  String _createdAtFromActivity(dynamic a) {
    if (a is Map) {
      final v =
          (a['created_at'] ?? a['createdAt'] ?? a['timestamp'] ?? '')
              .toString();
      if (v.trim().isNotEmpty) return v.trim();
    }
    return '—';
  }

  String _statusFromActivity(dynamic a) {
    if (a is Map) {
      final v = (a['status'] ?? a['ticket_status'] ?? '').toString();
      if (v.trim().isNotEmpty) return v.trim();
    }
    return '—';
  }

  String _subjectFromActivity(dynamic a) {
    if (a is Map) {
      final v =
          (a['subject'] ?? a['title'] ?? a['ticket_type'] ?? '').toString();
      if (v.trim().isNotEmpty) return v.trim();
    }
    return 'Ticket activity';
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'RECENT ACTIVITY'),
          SizedBox(height: 12),
          _SkeletonTile(),
          SizedBox(height: 10),
          _SkeletonTile(),
        ],
      );
    }
    final top = activities.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'RECENT ACTIVITY'),
        const SizedBox(height: 12),
        if (top.isEmpty)
          const _EmptyState(
            icon: Icons.history_outlined,
            message: 'No recent activity.',
          )
        else
          ...List.generate(top.length, (i) {
            final a = top[i];
            final id = _idFromActivity(a);
            final createdBy = _createdByFromActivity(a);
            final createdAt = _formatDate(_createdAtFromActivity(a));
            final subject = _subjectFromActivity(a);
            final status = _statusFromActivity(a);
            final color = _statusColor(status);
            return Padding(
              padding: EdgeInsets.only(bottom: i == top.length - 1 ? 0 : 10),
              child: _ActivityTile(
                title: 'Ticket #$id',
                subtitle: '$subject · By: $createdBy · $createdAt',
                status: status,
                statusColor: color,
                onTap:
                    id != '—'
                        ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => AdminTicketDetailsPage(
                                  ticketId: id,
                                  subject:
                                      subject != 'Ticket activity'
                                          ? subject
                                          : null,
                                ),
                          ),
                        )
                        : null,
              ),
            );
          }),
      ],
    );
  }
}

// ─── Skeleton Tile ────────────────────────────────────────────────────────────

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

// ─── Activity Tile ────────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  final String title, subtitle, status;
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

// ─── Settings Section ─────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final Map<String, dynamic>? me;
  const _SettingsSection({this.me});

  String? _extractString(List<String> keys) {
    if (me == null) return null;
    for (final k in keys) {
      final v = me![k];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return null;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'A';
  }

  @override
  Widget build(BuildContext context) {
    final name =
        _extractString(['name', 'full_name', 'fullName', 'username']) ??
        'Admin';
    final email = _extractString(['email', 'email_address']) ?? '—';
    final role =
        _extractString(['role', 'user_role', 'userRole', 'type']) ??
        'Administrator';
    final avatarUrl = _extractString([
      'avatar',
      'avatar_url',
      'photo',
      'profile_picture',
    ]);
    final initials = _initials(name);

    return Container(
      color: _surfaceSubtle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage your profile and app settings.',
            style: TextStyle(fontSize: 13, color: _inkSecondary),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminEditProfilePage(),
                  ),
                ),
            child: Container(
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
                    color: _primaryDark.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 2.5,
                          ),
                        ),
                        child:
                            avatarUrl != null && avatarUrl.startsWith('http')
                                ? ClipOval(
                                  child: Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (_, __, ___) =>
                                            _AvatarInitials(initials: initials),
                                  ),
                                )
                                : _AvatarInitials(initials: initials),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _primary.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: _primary,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              color: Colors.white.withOpacity(0.7),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                email,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            role,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.6),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'ACCOUNT'),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.manage_accounts_outlined,
            iconColor: _primary,
            title: 'Manage Users',
            subtitle: 'Create, update, and deactivate platform users.',
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminManageUsersPage(),
                  ),
                ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            icon: Icons.person_outline,
            iconColor: _primaryDark,
            title: 'Edit Profile',
            subtitle: 'Update your admin account information and preferences.',
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminEditProfilePage(),
                  ),
                ),
          ),
          const SizedBox(height: 20),
          const _SectionHeader(title: 'HELP'),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: Icons.menu_book_outlined,
            iconColor: _success,
            title: 'User Guide',
            subtitle: 'Read documentation and guides for the admin portal.',
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminUserGuidePage()),
                ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text(
                          'Logout',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        content: const Text(
                          'Are you sure you want to logout?',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6F6F6F),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEB1E23),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Logout',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                );
                if (confirm == true && context.mounted) {
                  await ApiService.logout();
                  if (context.mounted) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/', (route) => false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryDark,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text(
                'Logout',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Avatar Initials ──────────────────────────────────────────────────────────

class _AvatarInitials extends StatelessWidget {
  final String initials;
  const _AvatarInitials({required this.initials});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      initials,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    ),
  );
}

// ─── Settings Card ────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final VoidCallback onTap;

  const _SettingsCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
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
                  color: iconColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _inkTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Nav Bar ───────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool quickMenuOpen;
  final QuickActionType? quickAction;

  const _BottomNavBar({
    required this.selectedIndex,
    required this.onTap,
    required this.quickMenuOpen,
    required this.quickAction,
  });

  IconData _quickIcon() {
    if (quickMenuOpen) return Icons.close;
    switch (quickAction) {
      case QuickActionType.tickets:
        return Icons.confirmation_number_outlined;
      case QuickActionType.subscriptions:
        return Icons.subscriptions_outlined;
      case QuickActionType.billing:
        return Icons.receipt_long_outlined;
      default:
        return Icons.flash_on_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
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
            selected: selectedIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: Icons.group_outlined,
            label: 'Agents',
            selected: selectedIndex == 1,
            onTap: () => onTap(1),
          ),
          GestureDetector(
            onTap: () => onTap(2),
            child: Transform.translate(
              offset: const Offset(0, -12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: quickMenuOpen ? _surfaceSubtle : _primary,
                  shape: BoxShape.circle,
                  border:
                      quickMenuOpen
                          ? Border.all(color: _primary, width: 2)
                          : null,
                  boxShadow: [
                    BoxShadow(
                      color: _primaryDark.withOpacity(
                        quickMenuOpen ? 0.15 : 0.40,
                      ),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: AnimatedRotation(
                  turns: quickMenuOpen ? 0.125 : 0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Icon(
                    _quickIcon(),
                    color: quickMenuOpen ? _primary : Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          _NavItem(
            icon: Icons.people_alt_outlined,
            label: 'End Users',
            selected: selectedIndex == 3,
            onTap: () => onTap(3),
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            selected: selectedIndex == 4,
            onTap: () => onTap(4),
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

// ─── Subscription Tile ────────────────────────────────────────────────────────

class _SubscriptionTile extends StatelessWidget {
  final String nickname, serviceLineNumber, endDate, active;
  final VoidCallback? onTap;

  const _SubscriptionTile({
    required this.nickname,
    required this.serviceLineNumber,
    required this.endDate,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final au = active.toUpperCase();
    final Color color;
    final IconData icon;
    if (au.contains('EXPIRED') || au.contains('INACTIVE')) {
      color = _primaryDark;
      icon = Icons.cancel_outlined;
    } else if (au.contains('EXPIR')) {
      color = _warning;
      icon = Icons.schedule;
    } else {
      color = _success;
      icon = Icons.check_circle_outline;
    }

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
