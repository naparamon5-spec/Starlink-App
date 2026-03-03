import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../services/api_service.dart';
import 'sections/ticket/admin_tickets_page.dart';
import 'sections/agent/admin_agents_page.dart';
import 'sections/billing/admin_billing_page.dart';
import 'sections/subscription/admin_subscriptions_page.dart';
import 'sections/enduser/admin_end_users_page.dart';
import 'profile/admin_edit_profile_page.dart';
import 'profile/admin_manage_users_page.dart';
import 'profile/admin_user_guide_page.dart';

void main() {
  runApp(const AdminHomeScreen());
}

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF111921),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF197FE6),
          surface: Color(0xFF133343),
        ),
      ),
      home: const AdminDashboard(),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

enum QuickActionType { tickets, subscriptions, billing }

class _AdminDashboardState extends State<AdminDashboard> {
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

  String _displayNameFromMe(Map<String, dynamic>? me) {
    if (me == null) return 'Admin';
    final fullName =
        (me['full_name'] ?? me['name'] ?? me['fullname'] ?? '').toString();
    if (fullName.trim().isNotEmpty) return fullName.trim();

    final first = (me['first_name'] ?? me['firstname'] ?? '').toString();
    final last = (me['last_name'] ?? me['lastname'] ?? '').toString();
    final combined = ('$first $last').trim();
    if (combined.isNotEmpty) return combined;

    final email = (me['email'] ?? me['username'] ?? '').toString();
    if (email.trim().isNotEmpty) return email.trim();

    return 'Admin';
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

    int? _tryParseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    int? _countFromData(dynamic data) {
      if (data is num) return data.toInt();
      if (data is List) return data.length;
      if (data is Map) {
        // common total/count keys
        for (final k in const [
          'count',
          'total',
          'totalCount',
          'total_count',
          'total_items',
        ]) {
          final parsed = _tryParseInt(data[k]);
          if (parsed != null) return parsed;
        }

        // common list keys
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

        // sometimes the list is nested one more level deep
        for (final v in data.values) {
          final nested = _countFromData(v);
          if (nested != null) return nested;
        }
      }
      return null;
    }

    int _countFromResponse(dynamic res) {
      if (res is Map && res['status'] == 'success') {
        final fromData = _countFromData(res['data']);
        if (fromData != null) return fromData;
        final fromRaw = _countFromData(res['raw']);
        if (fromRaw != null) return fromRaw;
      }
      return 0;
    }

    List<dynamic> _listFromResponse(
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
      _openCount = _countFromResponse(results[0]);
      _inProgressCount = _countFromResponse(results[1]);
      _resolvedCount = _countFromResponse(results[2]);
      _closedCount = _countFromResponse(results[3]);
      _recentActivity = _listFromResponse(
        results[4],
        preferredKeys: const ['activity', 'activities', 'recent', 'events'],
      );
      _expiringSubscriptions = _listFromResponse(
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

  void _toggleQuickMenu() {
    setState(() => _quickMenuOpen = !_quickMenuOpen);
  }

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
                child: Text(
                  'Tap the Quick Action button\nto open Tickets, Subscriptions, or Billing.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
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
    final displayName = _displayNameFromMe(_me);
    return Scaffold(
      backgroundColor: const Color(0xFF111921),
      body: Stack(
        children: [
          // Main scroll content
          RefreshIndicator(
            onRefresh: _loadDashboard,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _AppBarDelegate(
                    displayName: displayName,
                    isLoading: _loadingDashboard,
                  ),
                ),
                if (_selectedIndex == 0 && _dashboardError != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _dashboardError!,
                                style: const TextStyle(
                                  color: Colors.white,
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

          // Dim overlay when quick menu open
          if (_quickMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _quickMenuOpen = false),
                child: Container(color: Colors.black.withOpacity(0.5)),
              ),
            ),

          // Animated quick action bubbles
          _QuickActionBubbles(
            isOpen: _quickMenuOpen,
            onSelect: _selectQuickAction,
            activeAction: _quickAction,
          ),

          // Floating Bottom Nav
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

    // FAB center: horizontally centered, sits 20px above the nav bar top
    // Nav bar: bottom=24, height≈72, FAB lifted 20px => FAB center Y from top:
    // screenHeight - 24 - 72/2 - 20 = screenHeight - 80
    final fabCenterX = screenWidth / 2;
    final fabCenterY = screenHeight - 80.0;

    // Bubble size
    const bubbleSize = 56.0;
    const labelHeight = 20.0;
    const totalBubbleHeight =
        bubbleSize + 6 + labelHeight; // circle + gap + label

    // Each bubble's final center offset from FAB center (arc going up)
    final actions = [
      _BubbleData(
        type: QuickActionType.tickets,
        icon: Icons.confirmation_number_outlined,
        label: 'Tickets',
        color: const Color(0xFFF59E0B),
        targetDx: -76.0,
        targetDy: -100.0,
        delay: 0.0,
      ),
      _BubbleData(
        type: QuickActionType.subscriptions,
        icon: Icons.subscriptions_outlined,
        label: 'Subs',
        color: const Color(0xFF197FE6),
        targetDx: 0.0,
        targetDy: -155.0,
        delay: 0.07,
      ),
      _BubbleData(
        type: QuickActionType.billing,
        icon: Icons.receipt_long_outlined,
        label: 'Billing',
        color: const Color(0xFF10B981),
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
                // Bubble top-left position
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
                                  : const Color(0xFF1A2A3A),
                          border: Border.all(
                            color: data.color,
                            width: widget.activeAction == data.type ? 0 : 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: data.color.withOpacity(
                                widget.activeAction == data.type ? 0.5 : 0.3,
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
                                  : Colors.white.withOpacity(0.9),
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

// ─── App Bar ────────────────────────────────────────────────────────────────

class _AppBarDelegate extends SliverPersistentHeaderDelegate {
  final String displayName;
  final bool isLoading;

  _AppBarDelegate({required this.displayName, required this.isLoading});

  @override
  double get minExtent => 72;
  @override
  double get maxExtent => 72;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFF111921).withOpacity(0.85),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF197FE6).withOpacity(0.4),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuBv4w3Ol5vcsB_cdKB1yxeoi2NE-VrnOVq-mM50oz2TKuAhSx-D9SthWKi52sm6ZUBQ3y_qeMB2H9JfZEf6ynjIFb_EL7eimG7FBoKEt4wpN6FCnsn-0hTzxoWGnwRtXoJ0bfg8iRGYjGrtWLynqZgw_gFzUgUnlL9ozAEYHk0YqqziMRZ_2Falj6-64pjJf3sjNhKfu_Fjql-vnquQTJlPau-oMdCuOot6VRUB5IYJhiY45kU_fjW3WEhrj4PDuhmUzgZ40Cczn-K4',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.person),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isLoading ? 'Loading profile…' : 'Welcome,',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              Positioned(
                right: 9,
                top: 9,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF197FE6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
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
            color: const Color(0xFF197FE6),
            onTap: () {
              // TODO: open create ticket page / web view
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickCreateButton(
            icon: Icons.person_add_outlined,
            label: 'New Agent',
            color: const Color(0xFF6366F1),
            onTap: () {
              // TODO: open create agent page / web view
            },
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
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.35), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
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

// ─── Ticket Overview Card (replaces System Health) ───────────────────────────

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
      if (open > 0) _BarSegment(flex: open, color: const Color(0xFFF59E0B)),
      if (inProgress > 0)
        _BarSegment(flex: inProgress, color: const Color(0xFF197FE6)),
      if (resolved > 0)
        _BarSegment(flex: resolved, color: const Color(0xFF10B981)),
      if (closed > 0) _BarSegment(flex: closed, color: const Color(0xFF64748B)),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2236), Color(0xFF133343)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E3A50), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ticket Overview',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isLoading
                        ? 'Loading tickets…'
                        : 'Today · $total total tickets',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Container(
                  //   width: 7,
                  //   height: 7,
                  //   decoration: const BoxDecoration(
                  //     color: Color(0xFF4ADE80),
                  //     shape: BoxShape.circle,
                  //   ),
                  // ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.confirmation_number, // ticket icon
                    size: 25, // adjust if needed
                    color: Colors.white,
                  ),
                  // const Text(
                  //   'LIVE',
                  //   style: TextStyle(
                  //     fontSize: 10,
                  //     fontWeight: FontWeight.w800,
                  //     color: Color(0xFF4ADE80),
                  //     letterSpacing: 1.2,
                  //   ),
                  // ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Segmented progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child:
                segments.isEmpty
                    ? Container(height: 10, color: const Color(0xFF1E293B))
                    : Row(children: segments),
          ),
          const SizedBox(height: 14),

          // Legend row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BarLegend(
                color: const Color(0xFFF59E0B),
                label: 'Open',
                count: open,
              ),
              _BarLegend(
                color: const Color(0xFF197FE6),
                label: 'In Progress',
                count: inProgress,
              ),
              _BarLegend(
                color: const Color(0xFF10B981),
                label: 'Resolved',
                count: resolved,
              ),
              _BarLegend(
                color: const Color(0xFF64748B),
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
    return Flexible(flex: flex, child: Container(height: 10, color: color));
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
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.only(left: 13),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Subscription Section ────────────────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'SUBSCRIPTION END DATES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 16),
          _SkeletonTile(),
          SizedBox(height: 12),
          _SkeletonTile(),
        ],
      );
    }

    final top = subscriptions.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SUBSCRIPTION END DATES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        if (top.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF133343),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Color(0xFF94A3B8)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No expiring subscriptions found.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...List.generate(top.length, (i) {
            final sub = top[i];
            final endDate = _endDateFromSub(sub);
            final nickname = _nicknameFromSub(sub);
            final serviceLine = _serviceLineFromSub(sub);
            final active = _activeFromSub(sub);
            return Padding(
              padding: EdgeInsets.only(bottom: i == top.length - 1 ? 0 : 12),
              child: _SubscriptionTile(
                nickname: (nickname.isNotEmpty ? nickname : _nameFromSub(sub)),
                serviceLineNumber: serviceLine.isEmpty ? '—' : serviceLine,
                endDate: endDate.isEmpty ? '—' : endDate,
                active: active.isEmpty ? '—' : active,
              ),
            );
          }),
      ],
    );
  }
}

// ─── Recent Activity ─────────────────────────────────────────────────────────

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
      final m = months[dt.month - 1];
      final d = dt.day.toString().padLeft(2, '0');
      final y = dt.year.toString();
      return '$m $d, $y';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'RECENT ACTIVITY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 16),
          _SkeletonTile(),
          SizedBox(height: 12),
          _SkeletonTile(),
        ],
      );
    }

    final top = activities.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RECENT ACTIVITY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 16),
        if (top.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF133343),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Color(0xFF94A3B8)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No recent activity.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...List.generate(top.length, (i) {
            final a = top[i];
            final id = _idFromActivity(a);
            final createdBy = _createdByFromActivity(a);
            final createdAt = _formatDate(_createdAtFromActivity(a));
            final subject = _subjectFromActivity(a);
            final status = _statusFromActivity(a);
            return Padding(
              padding: EdgeInsets.only(bottom: i == top.length - 1 ? 0 : 12),
              child: _ActivityTile(
                icon: Icons.history_toggle_off_outlined,
                iconColor: const Color(0xFF197FE6),
                iconBg: const Color(0xFF197FE6),
                title: 'Ticket #$id',
                subtitle: '$subject · By: $createdBy · $createdAt',
                status: status,
              ),
            );
          }),
      ],
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: const Color(0xFF133343),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: 160,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
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

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String status;

  const _ActivityTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF133343),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusBackgroundColor(status),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _statusBorderColor(status), width: 1),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: _statusTextColor(status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusBackgroundColor(String s) {
    final value = s.toLowerCase();

    if (value.contains('open')) {
      return const Color(0xFF64748B).withOpacity(0.15); // light gray
    }

    if (value.contains('progress')) {
      return const Color(0xFF197FE6).withOpacity(0.15);
    }

    if (value.contains('resolved')) {
      return const Color(0xFF10B981).withOpacity(0.15);
    }

    if (value.contains('closed')) {
      return const Color(0xFFF59E0B).withOpacity(0.15);
    }

    return const Color(0xFF64748B).withOpacity(0.15);
  }

  Color _statusBorderColor(String s) {
    final value = s.toLowerCase();

    if (value.contains('open')) {
      return const Color(0xFF64748B);
    }

    if (value.contains('progress')) {
      return const Color(0xFF197FE6);
    }

    if (value.contains('resolved')) {
      return const Color(0xFF10B981);
    }

    if (value.contains('closed')) {
      return const Color(0xFFF59E0B);
    }

    return const Color(0xFF64748B);
  }

  Color _statusTextColor(String s) {
    final value = s.toLowerCase();

    if (value.trim().isEmpty || value == '—') {
      return const Color(0xFFCBD5F5);
    }

    if (value.contains('open')) {
      return const Color.fromARGB(
        255,
        243,
        245,
        247,
      ); // darker gray for good contrast
    }

    if (value.contains('progress')) {
      return const Color(0xFF197FE6);
    }

    if (value.contains('resolved')) {
      return const Color(0xFF10B981);
    }

    if (value.contains('closed')) {
      return const Color(0xFFF59E0B);
    }

    return const Color.fromARGB(255, 100, 101, 105);
  }
}

// ─── Settings Section ────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111921),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage users, your profile, and app guides.',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 24),
          Card(
            color: const Color(0xFF133343),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.manage_accounts_outlined,
                color: Colors.white,
              ),
              title: const Text(
                'Manage Users',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Create, update, and deactivate platform users.',
                style: TextStyle(color: Color(0xFFBFDBFE)),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Color(0xFF94A3B8),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminManageUsersPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF133343),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(Icons.person_outline, color: Colors.white),
              title: const Text(
                'Edit Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Update your admin account information and preferences.',
                style: TextStyle(color: Color(0xFFBFDBFE)),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Color(0xFF94A3B8),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminEditProfilePage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: const Color(0xFF133343),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.menu_book_outlined,
                color: Colors.white,
              ),
              title: const Text(
                'User Guide',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Read documentation and guides for the admin portal.',
                style: TextStyle(color: Color(0xFFBFDBFE)),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: Color(0xFF94A3B8),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminUserGuidePage()),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).maybePop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.logout),
            label: const Text(
              'Logout',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 10),
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
          // Center FAB
          GestureDetector(
            onTap: () => onTap(2),
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color:
                      quickMenuOpen
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF197FE6),
                  shape: BoxShape.circle,
                  border:
                      quickMenuOpen
                          ? Border.all(color: const Color(0xFF197FE6), width: 2)
                          : null,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFF197FE6,
                      ).withOpacity(quickMenuOpen ? 0.2 : 0.45),
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
                    color:
                        quickMenuOpen ? const Color(0xFF197FE6) : Colors.white,
                    size: 28,
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
    final color = selected ? const Color(0xFF197FE6) : const Color(0xFF94A3B8);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
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

class _SubscriptionTile extends StatelessWidget {
  final String nickname;
  final String serviceLineNumber;
  final String endDate;
  final String active;

  const _SubscriptionTile({
    required this.nickname,
    required this.serviceLineNumber,
    required this.endDate,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    final activeUpper = active.toUpperCase();

    if (activeUpper.contains('EXPIRED') || activeUpper.contains('INACTIVE')) {
      color = const Color(0xFFEF4444);
      icon = Icons.cancel_outlined;
    } else if (activeUpper.contains('EXPIR')) {
      color = const Color(0xFFF59E0B);
      icon = Icons.schedule;
    } else {
      color = const Color(0xFF10B981);
      icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF133343),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          // ICON (same style as activity)
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),

          const SizedBox(width: 14),

          // TEXTS
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
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  serviceLineNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Expiration date: $endDate',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),

          // STATUS
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                active,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF64748B),
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
