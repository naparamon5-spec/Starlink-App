import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../services/api_service.dart';
import 'sections/ticket/admin_tickets_page.dart';
import 'sections/ticket/admin_ticket_details_page.dart';
import 'sections/agent/admin_agents_page.dart';
import 'sections/billing/admin_billing_page.dart';
import 'sections/subscription/admin_subscriptions_page.dart';
import 'sections/subscription/admin_subscription_details_page.dart';
import 'sections/enduser/admin_end_users_page.dart';
import 'profile/admin_edit_profile_page.dart';
import 'profile/admin_manage_users_page.dart';
import 'profile/admin_user_guide_page.dart';

// ── Design tokens (matching AdminBillingPage) ─────────────────────────────────
const _primary = Color(0xFF0F62FE);
const _success = Color(0xFF24A148);
const _warning = Color(0xFFFF832B);
const _danger = Color(0xFFDA1E28);
const _ink = Color(0xFF161616);
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

  void _toggleQuickMenu() => setState(() => _quickMenuOpen = !_quickMenuOpen);

  void _selectQuickAction(QuickActionType type) {
    setState(() {
      _selectedIndex = 2;
      _quickAction = type;
      _quickMenuOpen = false;
    });
  }

  void _onNavTap(int index) {
    if (index == 2) {
      _toggleQuickMenu();
      return;
    }
    setState(() {
      _selectedIndex = index;
      _quickMenuOpen = false;
    });
  }

  List<Widget> _buildBodySlivers() {
    switch (_selectedIndex) {
      case 0:
        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _QuickCreateSection(),
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
        return const [
          SliverFillRemaining(hasScrollBody: true, child: _SettingsSection()),
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
      backgroundColor: _surfaceSubtle,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadDashboard,
            color: _primary,
            strokeWidth: 2,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (_selectedIndex == 0 && _dashboardError != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
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

          if (_quickMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _quickMenuOpen = false),
                child: Container(color: Colors.black.withOpacity(0.3)),
              ),
            ),

          _QuickActionBubbles(
            isOpen: _quickMenuOpen,
            onSelect: _selectQuickAction,
            activeAction: _quickAction,
          ),

          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: _FloatingNavBar(
              selectedIndex: _selectedIndex,
              onTap: _onNavTap,
              quickMenuOpen: _quickMenuOpen,
              quickAction: _quickAction,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick Action Bubbles ─────────────────────────────────────────────────────

class _QuickActionBubbles extends StatefulWidget {
  final bool isOpen;
  final ValueChanged<QuickActionType> onSelect;
  final QuickActionType? activeAction;

  const _QuickActionBubbles({
    required this.isOpen,
    required this.onSelect,
    required this.activeAction,
  });

  @override
  State<_QuickActionBubbles> createState() => _QuickActionBubblesState();
}

class _QuickActionBubblesState extends State<_QuickActionBubbles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(_QuickActionBubbles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final fabCenterX = screenWidth / 2;
    final fabCenterY = screenHeight - 80.0;
    const bubbleSize = 56.0;
    const labelHeight = 20.0;
    const totalBubbleHeight = bubbleSize + 6 + labelHeight;

    final actions = [
      _BubbleData(
        type: QuickActionType.tickets,
        icon: Icons.confirmation_number_outlined,
        label: 'Tickets',
        color: _warning,
        targetDx: -76.0,
        targetDy: -100.0,
        delay: 0.0,
      ),
      _BubbleData(
        type: QuickActionType.subscriptions,
        icon: Icons.subscriptions_outlined,
        label: 'Subs',
        color: _primary,
        targetDx: 0.0,
        targetDy: -155.0,
        delay: 0.07,
      ),
      _BubbleData(
        type: QuickActionType.billing,
        icon: Icons.receipt_long_outlined,
        label: 'Billing',
        color: _success,
        targetDx: 76.0,
        targetDy: -100.0,
        delay: 0.14,
      ),
    ];

    return Stack(
      children:
          actions.map((data) {
            final anim = CurvedAnimation(
              parent: _controller,
              curve: Interval(
                data.delay,
                math.min(data.delay + 0.65, 1.0),
                curve: Curves.elasticOut,
              ),
            );

            return AnimatedBuilder(
              animation: anim,
              builder: (context, child) {
                final t = anim.value;
                final left = fabCenterX + data.targetDx * t - bubbleSize / 2;
                final top = fabCenterY + data.targetDy * t - bubbleSize / 2;
                return Positioned(
                  left: left,
                  top: top,
                  child: Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: t.clamp(0.0, 1.0),
                      alignment: Alignment.bottomCenter,
                      child: child,
                    ),
                  ),
                );
              },
              child: GestureDetector(
                onTap: () => widget.onSelect(data.type),
                child: SizedBox(
                  width: bubbleSize,
                  height: totalBubbleHeight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: bubbleSize,
                        height: bubbleSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              widget.activeAction == data.type
                                  ? data.color
                                  : _surface,
                          border: Border.all(
                            color: data.color,
                            width: widget.activeAction == data.type ? 0 : 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: data.color.withOpacity(
                                widget.activeAction == data.type ? 0.35 : 0.2,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          data.icon,
                          color:
                              widget.activeAction == data.type
                                  ? Colors.white
                                  : data.color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color:
                              widget.activeAction == data.type
                                  ? data.color
                                  : _ink,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}

class _BubbleData {
  final QuickActionType type;
  final IconData icon;
  final String label;
  final Color color;
  final double targetDx;
  final double targetDy;
  final double delay;

  const _BubbleData({
    required this.type,
    required this.icon,
    required this.label,
    required this.color,
    required this.targetDx,
    required this.targetDy,
    required this.delay,
  });
}

// ─── Quick Create Buttons ─────────────────────────────────────────────────────

class _QuickCreateSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickCreateButton(
            icon: Icons.confirmation_number_outlined,
            label: 'New Ticket',
            color: _primary,
            onTap: () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickCreateButton(
            icon: Icons.person_add_outlined,
            label: 'New Agent',
            color: const Color(0xFF6929C4),
            onTap: () {},
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
  final int open;
  final int inProgress;
  final int resolved;
  final int closed;

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
      if (inProgress > 0) _BarSegment(flex: inProgress, color: _primary),
      if (resolved > 0) _BarSegment(flex: resolved, color: _success),
      if (closed > 0) _BarSegment(flex: closed, color: const Color(0xFFA8A8A8)),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F62FE), Color(0xFF0043CE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.28),
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
                color: _primary,
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
  Widget build(BuildContext context) {
    return Flexible(flex: flex, child: Container(height: 8, color: color));
  }
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
      final name =
          (sub['name'] ??
                  sub['customer_name'] ??
                  sub['end_user_name'] ??
                  sub['customer'] ??
                  sub['user'] ??
                  '')
              .toString();
      if (name.trim().isNotEmpty) return name.trim();
    }
    return 'Subscription';
  }

  String _nicknameFromSub(dynamic sub) {
    if (sub is Map) {
      final nickname = (sub['nickname'] ?? sub['name'] ?? '').toString();
      if (nickname.trim().isNotEmpty) return nickname.trim();
    }
    return '';
  }

  String _serviceLineFromSub(dynamic sub) {
    if (sub is Map) {
      final sl =
          (sub['serviceLineNumber'] ??
                  sub['service_line_number'] ??
                  sub['serviceLine'] ??
                  '')
              .toString();
      if (sl.trim().isNotEmpty) return sl.trim();
    }
    return '';
  }

  String _endDateFromSub(dynamic sub) {
    if (sub is Map) {
      final raw =
          (sub['end_date'] ??
                  sub['expires_at'] ??
                  sub['expiry_date'] ??
                  sub['endDate'] ??
                  sub['end'] ??
                  '')
              .toString();
      if (raw.trim().isNotEmpty) return raw.trim();
    }
    return '';
  }

  String _activeFromSub(dynamic sub) {
    if (sub is Map) {
      final active = (sub['active'] ?? sub['status'] ?? '').toString();
      if (active.trim().isNotEmpty) return active.trim();
    }
    return '';
  }

  void _openSubscriptionDetails(
    BuildContext context, {
    required String serviceLineNumber,
    required String nickname,
  }) {
    if (serviceLineNumber.trim().isEmpty || serviceLineNumber.trim() == '—')
      return;
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
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _inkTertiary,
        letterSpacing: 1.1,
      ),
    );
  }
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
      final id = (a['id'] ?? a['ticket_id'] ?? '').toString();
      if (id.trim().isNotEmpty) return id.trim();
    }
    return '—';
  }

  String _createdByFromActivity(dynamic a) {
    if (a is Map) {
      final cb = (a['created_by'] ?? a['createdBy'] ?? '').toString();
      if (cb.trim().isNotEmpty) return cb.trim();
    }
    return '—';
  }

  String _createdAtFromActivity(dynamic a) {
    if (a is Map) {
      final ca =
          (a['created_at'] ?? a['createdAt'] ?? a['timestamp'] ?? '')
              .toString();
      if (ca.trim().isNotEmpty) return ca.trim();
    }
    return '—';
  }

  String _statusFromActivity(dynamic a) {
    if (a is Map) {
      final status = (a['status'] ?? a['ticket_status'] ?? '').toString();
      if (status.trim().isNotEmpty) return status.trim();
    }
    return '—';
  }

  String _subjectFromActivity(dynamic a) {
    if (a is Map) {
      final subject =
          (a['subject'] ?? a['title'] ?? a['ticket_type'] ?? '').toString();
      if (subject.trim().isNotEmpty) return subject.trim();
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
    if (v.contains('progress')) return _primary;
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

// ─── Settings Section ─────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surfaceSubtle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
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
            'Manage users, your profile, and app guides.',
            style: TextStyle(fontSize: 13, color: _inkSecondary),
          ),
          const SizedBox(height: 24),
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
            iconColor: const Color(0xFF6929C4),
            title: 'Edit Profile',
            subtitle: 'Update your admin account information and preferences.',
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminEditProfilePage(),
                  ),
                ),
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _danger,
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

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
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

// ─── Floating Bottom Nav ──────────────────────────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool quickMenuOpen;
  final QuickActionType? quickAction;

  const _FloatingNavBar({
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
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
              offset: const Offset(0, -20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: quickMenuOpen ? _surfaceSubtle : _primary,
                  shape: BoxShape.circle,
                  border:
                      quickMenuOpen
                          ? Border.all(color: _primary, width: 2)
                          : null,
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(quickMenuOpen ? 0.15 : 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
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
                    size: 26,
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
  final String nickname;
  final String serviceLineNumber;
  final String endDate;
  final String active;
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
    Color color;
    IconData icon;

    final activeUpper = active.toUpperCase();
    if (activeUpper.contains('EXPIRED') || activeUpper.contains('INACTIVE')) {
      color = _danger;
      icon = Icons.cancel_outlined;
    } else if (activeUpper.contains('EXPIR')) {
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
