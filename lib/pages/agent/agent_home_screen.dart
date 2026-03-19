import 'package:flutter/material.dart';
import 'package:starlink_app/pages/agent/profile/agent_edit_profile_page.dart';
import 'package:starlink_app/pages/agent/profile/agent_manage_users_page.dart';
import 'package:starlink_app/pages/agent/profile/agent_user_guide_page.dart';
import 'sections/agent/agent_agents_page.dart';
import 'sections/billing/agent_billing_page.dart';
import 'sections/enduser/agent_end_users_page.dart';
import 'sections/subscription/agent_subscriptions_page.dart';
import 'sections/ticket/agent_tickets_page.dart';

import 'dart:math' as math;

void main() {
  runApp(const AgentApp());
}

class AgentApp extends StatelessWidget {
  const AgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agent Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1923),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          surface: Color(0xFF162032),
        ),
      ),
      home: const AgentDashboard(),
    );
  }
}

// ─── Enums ────────────────────────────────────────────────────────────────────

enum AgentQuickAction { tickets, subscriptions, billing }

// ─── Agent Dashboard ──────────────────────────────────────────────────────────

class AgentDashboard extends StatefulWidget {
  const AgentDashboard({super.key});

  @override
  State<AgentDashboard> createState() => _AgentDashboardState();
}

class _AgentDashboardState extends State<AgentDashboard> {
  int _selectedIndex = 0;
  AgentQuickAction? _quickAction;
  bool _quickMenuOpen = false;

  void _toggleQuickMenu() {
    setState(() => _quickMenuOpen = !_quickMenuOpen);
  }

  void _selectQuickAction(AgentQuickAction type) {
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _AgentStatsHero(),
                const SizedBox(height: 16),
                _TicketOverviewCard(),
                const SizedBox(height: 16),
                _MyPerformanceSection(),
                const SizedBox(height: 16),
                _RecentActivitySection(),
              ]),
            ),
          ),
        ];
      case 1:
        return [
          const SliverFillRemaining(
            hasScrollBody: true,
            child: AgentTeamPage(),
          ),
        ];
      case 2:
        if (_quickAction == AgentQuickAction.tickets) {
          return [
            const SliverFillRemaining(
              hasScrollBody: true,
              child: MyTicketsPage(),
            ),
          ];
        } else if (_quickAction == AgentQuickAction.subscriptions) {
          return [
            const SliverFillRemaining(
              hasScrollBody: true,
              child: SubscriptionsPage(),
            ),
          ];
        } else if (_quickAction == AgentQuickAction.billing) {
          return [
            const SliverFillRemaining(
              hasScrollBody: true,
              child: BillingPage(),
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
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ];
        }
      case 3:
        return [
          const SliverFillRemaining(hasScrollBody: true, child: EndUsersPage()),
        ];
      case 4:
        return const [
          SliverFillRemaining(hasScrollBody: true, child: _AgentSettingsPage()),
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
      backgroundColor: const Color(0xFF0F1923),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _AgentAppBarDelegate(),
              ),
              ..._buildBodySlivers(),
            ],
          ),
          if (_quickMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _quickMenuOpen = false),
                child: Container(color: Colors.black.withOpacity(0.55)),
              ),
            ),
          _AgentQuickBubbles(
            isOpen: _quickMenuOpen,
            onSelect: _selectQuickAction,
            activeAction: _quickAction,
          ),
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: _AgentFloatingNav(
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

// ─── App Bar ──────────────────────────────────────────────────────────────────

class _AgentAppBarDelegate extends SliverPersistentHeaderDelegate {
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
      color: const Color(0xFF0F1923).withOpacity(0.92),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'JD',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0F1923),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'AGENT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6366F1),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'James Davis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.1,
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
                  color: const Color(0xFF162032),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E3050)),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Positioned(
                right: 9,
                top: 9,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6366F1),
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
      false;
}

// ─── Quick Bubbles: Tickets · Subscriptions · Billing ─────────────────────────

class _AgentQuickBubbles extends StatefulWidget {
  final bool isOpen;
  final ValueChanged<AgentQuickAction> onSelect;
  final AgentQuickAction? activeAction;

  const _AgentQuickBubbles({
    required this.isOpen,
    required this.onSelect,
    required this.activeAction,
  });

  @override
  State<_AgentQuickBubbles> createState() => _AgentQuickBubblesState();
}

class _AgentQuickBubblesState extends State<_AgentQuickBubbles>
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
  void didUpdateWidget(_AgentQuickBubbles oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.isOpen ? _controller.forward() : _controller.reverse();
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

    // Mirrors Admin: Tickets · Subscriptions · Billing
    final actions = [
      _BubbleItem(
        type: AgentQuickAction.tickets,
        icon: Icons.confirmation_number_outlined,
        label: 'Tickets',
        color: const Color(0xFFF59E0B),
        targetDx: -76.0,
        targetDy: -100.0,
        delay: 0.0,
      ),
      _BubbleItem(
        type: AgentQuickAction.subscriptions,
        icon: Icons.subscriptions_outlined,
        label: 'Subs',
        color: const Color(0xFF6366F1),
        targetDx: 0.0,
        targetDy: -155.0,
        delay: 0.07,
      ),
      _BubbleItem(
        type: AgentQuickAction.billing,
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
                                  : const Color(0xFF162032),
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

class _BubbleItem {
  final AgentQuickAction type;
  final IconData icon;
  final String label;
  final Color color;
  final double targetDx, targetDy, delay;
  const _BubbleItem({
    required this.type,
    required this.icon,
    required this.label,
    required this.color,
    required this.targetDx,
    required this.targetDy,
    required this.delay,
  });
}

// ─── Floating Nav: Dashboard · Agents · FAB · End Users · Settings ────────────

class _AgentFloatingNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool quickMenuOpen;
  final AgentQuickAction? quickAction;

  const _AgentFloatingNav({
    required this.selectedIndex,
    required this.onTap,
    required this.quickMenuOpen,
    required this.quickAction,
  });

  IconData _quickIcon() {
    if (quickMenuOpen) return Icons.close;
    switch (quickAction) {
      case AgentQuickAction.tickets:
        return Icons.confirmation_number_outlined;
      case AgentQuickAction.subscriptions:
        return Icons.subscriptions_outlined;
      case AgentQuickAction.billing:
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
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 0 – Dashboard
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            selected: selectedIndex == 0,
            onTap: () => onTap(0),
          ),
          // 1 – Agents
          _NavItem(
            icon: Icons.group_outlined,
            label: 'Agents',
            selected: selectedIndex == 1,
            onTap: () => onTap(1),
          ),
          // 2 – Center FAB
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
                          ? const Color(0xFF1E2A40)
                          : const Color(0xFF6366F1),
                  shape: BoxShape.circle,
                  border:
                      quickMenuOpen
                          ? Border.all(color: const Color(0xFF6366F1), width: 2)
                          : null,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFF6366F1,
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
                        quickMenuOpen ? const Color(0xFF6366F1) : Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
          // 3 – End Users
          _NavItem(
            icon: Icons.people_alt_outlined,
            label: 'End Users',
            selected: selectedIndex == 3,
            onTap: () => onTap(3),
          ),
          // 4 – Settings
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
    final color = selected ? const Color(0xFF6366F1) : const Color(0xFF94A3B8);
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

// ─── Dashboard Widgets ────────────────────────────────────────────────────────

class _AgentStatsHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1060), Color(0xFF162032)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'My Performance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.trending_up, color: Color(0xFF22C55E), size: 13),
                    SizedBox(width: 4),
                    Text(
                      'On Track',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroStat(
                value: '12',
                label: 'Assigned',
                color: const Color(0xFF6366F1),
              ),
              const SizedBox(width: 24),
              _HeroStat(
                value: '5',
                label: 'Open',
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 24),
              _HeroStat(
                value: '7',
                label: 'Resolved',
                color: const Color(0xFF10B981),
              ),
              const Spacer(),
              _CircularProgress(
                resolved: 7,
                total: 12,
                color: const Color(0xFF6366F1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Flexible(
                  flex: 5,
                  child: Container(height: 6, color: const Color(0xFFF59E0B)),
                ),
                Flexible(
                  flex: 7,
                  child: Container(height: 6, color: const Color(0xFF6366F1)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Avg. response time: 1h 24m · Rating: 4.8 ⭐',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _HeroStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }
}

class _CircularProgress extends StatelessWidget {
  final int resolved, total;
  final Color color;
  const _CircularProgress({
    required this.resolved,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? resolved / total : 0.0;
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(58, 58),
            painter: _ArcPainter(progress: pct, color: color),
          ),
          Text(
            '${(pct * 100).round()}%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _ArcPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TicketOverviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const open = 5, inProgress = 4, resolved = 7, pending = 2;
    const total = open + inProgress + resolved + pending;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF162032),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E3050), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Ticket Overview',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.25),
                  ),
                ),
                child: Text(
                  '$total Total',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Flexible(
                  flex: open,
                  child: Container(height: 8, color: const Color(0xFFF59E0B)),
                ),
                Flexible(
                  flex: inProgress,
                  child: Container(height: 8, color: const Color(0xFF6366F1)),
                ),
                Flexible(
                  flex: resolved,
                  child: Container(height: 8, color: const Color(0xFF10B981)),
                ),
                Flexible(
                  flex: pending,
                  child: Container(height: 8, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TicketLegend(
                color: const Color(0xFFF59E0B),
                label: 'Open',
                count: open,
              ),
              _TicketLegend(
                color: const Color(0xFF6366F1),
                label: 'In Progress',
                count: inProgress,
              ),
              _TicketLegend(
                color: const Color(0xFF10B981),
                label: 'Resolved',
                count: resolved,
              ),
              _TicketLegend(
                color: const Color(0xFF64748B),
                label: 'Pending',
                count: pending,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TicketLegend extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _TicketLegend({
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
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.only(left: 12),
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

class _MyPerformanceSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'MY STATS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
                letterSpacing: 1.0,
              ),
            ),
            Text(
              'This Week',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6366F1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.timer_outlined,
                iconColor: const Color(0xFF6366F1),
                label: 'Avg Response',
                value: '1h 24m',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.star_outline,
                iconColor: const Color(0xFFF59E0B),
                label: 'Satisfaction',
                value: '4.8 / 5',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle_outline,
                iconColor: const Color(0xFF10B981),
                label: 'Resolved',
                value: '7',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, value;
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF162032),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3050)),
      ),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RECENT ACTIVITY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        _ActivityTile(
          icon: Icons.add_circle_outline,
          iconColor: const Color(0xFF6366F1),
          title: 'New ticket assigned to you',
          subtitle: 'TKT-2041 · Acme Corp · 10 min ago',
        ),
        const SizedBox(height: 10),
        _ActivityTile(
          icon: Icons.check_circle_outline,
          iconColor: const Color(0xFF10B981),
          title: 'Ticket resolved',
          subtitle: 'TKT-2038 · BlueSky Ltd. · 1 hour ago',
        ),
        const SizedBox(height: 10),
        _ActivityTile(
          icon: Icons.chat_bubble_outline,
          iconColor: const Color(0xFFF59E0B),
          title: 'New reply from end user',
          subtitle: 'TKT-2035 · NovaTech Inc. · 2 hours ago',
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  const _ActivityTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF162032),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E3050)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
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
          const Icon(Icons.chevron_right, color: Color(0xFF64748B), size: 20),
        ],
      ),
    );
  }
}

// ─── Agents Tab (index 1) ─────────────────────────────────────────────────────

// class _AgentTeamPage extends StatelessWidget {
//   const _AgentTeamPage();

//   static const _agents = [
//     _AgentData(
//       name: 'James Davis',
//       role: 'Support Agent · L2',
//       initials: 'JD',
//       status: 'Online',
//       statusColor: Color(0xFF22C55E),
//       tickets: 12,
//       resolved: 7,
//       gradA: Color(0xFF6366F1),
//       gradB: Color(0xFF8B5CF6),
//     ),
//     _AgentData(
//       name: 'Maria Santos',
//       role: 'Support Agent · L1',
//       initials: 'MS',
//       status: 'Online',
//       statusColor: Color(0xFF22C55E),
//       tickets: 9,
//       resolved: 6,
//       gradA: Color(0xFF10B981),
//       gradB: Color(0xFF0EA5E9),
//     ),
//     _AgentData(
//       name: 'Kevin Lee',
//       role: 'Senior Agent · L3',
//       initials: 'KL',
//       status: 'Busy',
//       statusColor: Color(0xFFF59E0B),
//       tickets: 15,
//       resolved: 12,
//       gradA: Color(0xFFF59E0B),
//       gradB: Color(0xFFF43F5E),
//     ),
//     _AgentData(
//       name: 'Priya Nair',
//       role: 'Support Agent · L2',
//       initials: 'PN',
//       status: 'Away',
//       statusColor: Color(0xFF64748B),
//       tickets: 6,
//       resolved: 5,
//       gradA: Color(0xFF0EA5E9),
//       gradB: Color(0xFF6366F1),
//     ),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
//           color: const Color(0xFF0F1923),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Agent Team',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//               ),
//               const SizedBox(height: 10),
//               Container(
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF162032),
//                   borderRadius: BorderRadius.circular(14),
//                   border: Border.all(color: const Color(0xFF1E3050)),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceAround,
//                   children: [
//                     _TStat(
//                       value: '${_agents.length}',
//                       label: 'Total',
//                       color: const Color(0xFF6366F1),
//                     ),
//                     Container(
//                       width: 1,
//                       height: 28,
//                       color: const Color(0xFF1E3050),
//                     ),
//                     _TStat(
//                       value: '2',
//                       label: 'Online',
//                       color: const Color(0xFF22C55E),
//                     ),
//                     Container(
//                       width: 1,
//                       height: 28,
//                       color: const Color(0xFF1E3050),
//                     ),
//                     _TStat(
//                       value: '1',
//                       label: 'Busy',
//                       color: const Color(0xFFF59E0B),
//                     ),
//                     Container(
//                       width: 1,
//                       height: 28,
//                       color: const Color(0xFF1E3050),
//                     ),
//                     _TStat(
//                       value: '1',
//                       label: 'Away',
//                       color: const Color(0xFF64748B),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//         Expanded(
//           child: ListView.separated(
//             padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
//             itemCount: _agents.length,
//             separatorBuilder: (_, __) => const SizedBox(height: 10),
//             itemBuilder: (_, i) => _AgentTeamCard(data: _agents[i]),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _AgentData {
//   final String name, role, initials, status;
//   final Color statusColor, gradA, gradB;
//   final int tickets, resolved;
//   const _AgentData({
//     required this.name,
//     required this.role,
//     required this.initials,
//     required this.status,
//     required this.statusColor,
//     required this.tickets,
//     required this.resolved,
//     required this.gradA,
//     required this.gradB,
//   });
// }

// class _TStat extends StatelessWidget {
//   final String value, label;
//   final Color color;
//   const _TStat({required this.value, required this.label, required this.color});

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Text(
//           value,
//           style: TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//             color: color,
//           ),
//         ),
//         const SizedBox(height: 2),
//         Text(
//           label,
//           style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
//         ),
//       ],
//     );
//   }
// }

// class _AgentTeamCard extends StatelessWidget {
//   final _AgentData data;
//   const _AgentTeamCard({required this.data});

//   @override
//   Widget build(BuildContext context) {
//     final pct = data.tickets > 0 ? data.resolved / data.tickets : 0.0;
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: const Color(0xFF162032),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFF1E3050)),
//       ),
//       child: Row(
//         children: [
//           Stack(
//             children: [
//               Container(
//                 width: 48,
//                 height: 48,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   gradient: LinearGradient(
//                     colors: [data.gradA, data.gradB],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                 ),
//                 child: Center(
//                   child: Text(
//                     data.initials,
//                     style: const TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ),
//               ),
//               Positioned(
//                 right: 1,
//                 bottom: 1,
//                 child: Container(
//                   width: 12,
//                   height: 12,
//                   decoration: BoxDecoration(
//                     color: data.statusColor,
//                     shape: BoxShape.circle,
//                     border: Border.all(
//                       color: const Color(0xFF162032),
//                       width: 2,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Text(
//                       data.name,
//                       style: const TextStyle(
//                         fontSize: 13,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 6,
//                         vertical: 2,
//                       ),
//                       decoration: BoxDecoration(
//                         color: data.statusColor.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(6),
//                       ),
//                       child: Text(
//                         data.status,
//                         style: TextStyle(
//                           fontSize: 9,
//                           fontWeight: FontWeight.w700,
//                           color: data.statusColor,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   data.role,
//                   style: const TextStyle(
//                     fontSize: 11,
//                     color: Color(0xFF94A3B8),
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: ClipRRect(
//                         borderRadius: BorderRadius.circular(4),
//                         child: Stack(
//                           children: [
//                             Container(
//                               height: 4,
//                               color: const Color(0xFF6366F1).withOpacity(0.15),
//                             ),
//                             FractionallySizedBox(
//                               widthFactor: pct,
//                               child: Container(
//                                 height: 4,
//                                 decoration: BoxDecoration(
//                                   gradient: LinearGradient(
//                                     colors: [data.gradA, data.gradB],
//                                   ),
//                                   borderRadius: BorderRadius.circular(4),
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     Text(
//                       '${data.resolved}/${data.tickets}',
//                       style: const TextStyle(
//                         fontSize: 10,
//                         color: Color(0xFF94A3B8),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           const SizedBox(width: 8),
//           const Icon(Icons.chevron_right, color: Color(0xFF64748B), size: 20),
//         ],
//       ),
//     );
//   }
// }

// ─── My Tickets (Quick Action) ────────────────────────────────────────────────

// class _MyTicketsPage extends StatefulWidget {
//   const _MyTicketsPage();

//   @override
//   State<_MyTicketsPage> createState() => _MyTicketsPageState();
// }

// class _MyTicketsPageState extends State<_MyTicketsPage> {
//   int _filterIndex = 0;
//   final _filters = ['All', 'Open', 'In Progress', 'Resolved', 'Pending'];

//   static const _tickets = [
//     _TicketItem(
//       id: 'TKT-2041',
//       title: 'Cannot login after password reset',
//       company: 'Acme Corp',
//       priority: 'High',
//       status: 'Open',
//       time: '10 min ago',
//       priorityColor: Color(0xFFF43F5E),
//       statusColor: Color(0xFFF59E0B),
//     ),
//     _TicketItem(
//       id: 'TKT-2040',
//       title: 'Dashboard widget not loading data',
//       company: 'NovaTech Inc.',
//       priority: 'Medium',
//       status: 'In Progress',
//       time: '45 min ago',
//       priorityColor: Color(0xFFF59E0B),
//       statusColor: Color(0xFF6366F1),
//     ),
//     _TicketItem(
//       id: 'TKT-2039',
//       title: 'Bulk export returns empty file',
//       company: 'PixelWave Co.',
//       priority: 'High',
//       status: 'Open',
//       time: '1 hour ago',
//       priorityColor: Color(0xFFF43F5E),
//       statusColor: Color(0xFFF59E0B),
//     ),
//     _TicketItem(
//       id: 'TKT-2038',
//       title: 'Email notifications delayed',
//       company: 'BlueSky Ltd.',
//       priority: 'Low',
//       status: 'Resolved',
//       time: '1 hour ago',
//       priorityColor: Color(0xFF10B981),
//       statusColor: Color(0xFF10B981),
//     ),
//     _TicketItem(
//       id: 'TKT-2036',
//       title: 'API key regeneration failing',
//       company: 'DataStream AI',
//       priority: 'Medium',
//       status: 'Pending',
//       time: '3 hours ago',
//       priorityColor: Color(0xFFF59E0B),
//       statusColor: Color(0xFF64748B),
//     ),
//     _TicketItem(
//       id: 'TKT-2033',
//       title: 'User role permissions not saving',
//       company: 'CloudSync GmbH',
//       priority: 'Medium',
//       status: 'In Progress',
//       time: '5 hours ago',
//       priorityColor: Color(0xFFF59E0B),
//       statusColor: Color(0xFF6366F1),
//     ),
//   ];

//   List<_TicketItem> get _filtered =>
//       _filterIndex == 0
//           ? _tickets
//           : _tickets.where((t) => t.status == _filters[_filterIndex]).toList();

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
//           color: const Color(0xFF0F1923),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     'My Tickets',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),
//                   GestureDetector(
//                     onTap: () {},
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 7,
//                       ),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFF6366F1),
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Row(
//                         children: const [
//                           Icon(Icons.add, color: Colors.white, size: 16),
//                           SizedBox(width: 4),
//                           Text(
//                             'Create Ticket',
//                             style: TextStyle(
//                               fontSize: 12,
//                               fontWeight: FontWeight.w700,
//                               color: Colors.white,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 12),
//               SingleChildScrollView(
//                 scrollDirection: Axis.horizontal,
//                 child: Row(
//                   children:
//                       _filters.asMap().entries.map((e) {
//                         final sel = e.key == _filterIndex;
//                         return GestureDetector(
//                           onTap: () => setState(() => _filterIndex = e.key),
//                           child: Container(
//                             margin: const EdgeInsets.only(right: 8),
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 14,
//                               vertical: 7,
//                             ),
//                             decoration: BoxDecoration(
//                               color:
//                                   sel
//                                       ? const Color(0xFF6366F1)
//                                       : const Color(0xFF162032),
//                               borderRadius: BorderRadius.circular(20),
//                               border: Border.all(
//                                 color:
//                                     sel
//                                         ? const Color(0xFF6366F1)
//                                         : const Color(0xFF1E3050),
//                               ),
//                             ),
//                             child: Text(
//                               e.value,
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.w600,
//                                 color:
//                                     sel
//                                         ? Colors.white
//                                         : const Color(0xFF94A3B8),
//                               ),
//                             ),
//                           ),
//                         );
//                       }).toList(),
//                 ),
//               ),
//             ],
//           ),
//         ),
//         Expanded(
//           child:
//               _filtered.isEmpty
//                   ? Center(
//                     child: Text(
//                       'No ${_filters[_filterIndex]} tickets',
//                       style: const TextStyle(
//                         color: Color(0xFF64748B),
//                         fontSize: 14,
//                       ),
//                     ),
//                   )
//                   : ListView.separated(
//                     padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
//                     itemCount: _filtered.length,
//                     separatorBuilder: (_, __) => const SizedBox(height: 10),
//                     itemBuilder: (_, i) => _TicketCard(data: _filtered[i]),
//                   ),
//         ),
//       ],
//     );
//   }
// }

// class _TicketItem {
//   final String id, title, company, priority, status, time;
//   final Color priorityColor, statusColor;
//   const _TicketItem({
//     required this.id,
//     required this.title,
//     required this.company,
//     required this.priority,
//     required this.status,
//     required this.time,
//     required this.priorityColor,
//     required this.statusColor,
//   });
// }

// class _TicketCard extends StatelessWidget {
//   final _TicketItem data;
//   const _TicketCard({required this.data});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: const Color(0xFF162032),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFF1E3050)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Text(
//                 data.id,
//                 style: const TextStyle(
//                   fontSize: 11,
//                   color: Color(0xFF64748B),
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
//                 decoration: BoxDecoration(
//                   color: data.priorityColor.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//                 child: Text(
//                   data.priority,
//                   style: TextStyle(
//                     fontSize: 9,
//                     fontWeight: FontWeight.w700,
//                     color: data.priorityColor,
//                   ),
//                 ),
//               ),
//               const Spacer(),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//                 decoration: BoxDecoration(
//                   color: data.statusColor.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//                 child: Text(
//                   data.status,
//                   style: TextStyle(
//                     fontSize: 9,
//                     fontWeight: FontWeight.w700,
//                     color: data.statusColor,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Text(
//             data.title,
//             style: const TextStyle(
//               fontSize: 13,
//               fontWeight: FontWeight.bold,
//               color: Colors.white,
//             ),
//           ),
//           const SizedBox(height: 6),
//           Row(
//             children: [
//               const Icon(
//                 Icons.business_outlined,
//                 size: 12,
//                 color: Color(0xFF64748B),
//               ),
//               const SizedBox(width: 4),
//               Text(
//                 data.company,
//                 style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
//               ),
//               const Spacer(),
//               const Icon(Icons.access_time, size: 11, color: Color(0xFF64748B)),
//               const SizedBox(width: 3),
//               Text(
//                 data.time,
//                 style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// ─── Subscriptions (Quick Action) ────────────────────────────────────────────

// class _SubscriptionsPage extends StatelessWidget {
//   const _SubscriptionsPage();

//   static const _subs = [
//     _SubItem(
//       company: 'Acme Corp',
//       plan: 'Enterprise',
//       seats: 50,
//       status: 'Expiring',
//       renewDate: 'Mar 06, 2026',
//       mrr: '\$2,400',
//       statusColor: Color(0xFFF43F5E),
//     ),
//     _SubItem(
//       company: 'NovaTech Inc.',
//       plan: 'Enterprise',
//       seats: 30,
//       status: 'Active',
//       renewDate: 'Apr 15, 2026',
//       mrr: '\$1,800',
//       statusColor: Color(0xFF10B981),
//     ),
//     _SubItem(
//       company: 'BlueSky Ltd.',
//       plan: 'Pro',
//       seats: 10,
//       status: 'Active',
//       renewDate: 'Apr 28, 2026',
//       mrr: '\$490',
//       statusColor: Color(0xFF10B981),
//     ),
//     _SubItem(
//       company: 'PixelWave Co.',
//       plan: 'Pro',
//       seats: 8,
//       status: 'Expiring',
//       renewDate: 'Mar 09, 2026',
//       mrr: '\$392',
//       statusColor: Color(0xFFF59E0B),
//     ),
//     _SubItem(
//       company: 'DataStream AI',
//       plan: 'Enterprise',
//       seats: 20,
//       status: 'Active',
//       renewDate: 'May 01, 2026',
//       mrr: '\$960',
//       statusColor: Color(0xFF10B981),
//     ),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
//           color: const Color(0xFF0F1923),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Subscriptions',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//               ),
//               const SizedBox(height: 10),
//               Container(
//                 padding: const EdgeInsets.all(14),
//                 decoration: BoxDecoration(
//                   gradient: const LinearGradient(
//                     colors: [Color(0xFF1A1060), Color(0xFF0C1424)],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                   borderRadius: BorderRadius.circular(14),
//                   border: Border.all(
//                     color: const Color(0xFF6366F1).withOpacity(0.2),
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: const [
//                         Text(
//                           'Active Subscriptions',
//                           style: TextStyle(
//                             fontSize: 11,
//                             color: Color(0xFF94A3B8),
//                           ),
//                         ),
//                         SizedBox(height: 4),
//                         Text(
//                           '5 Total',
//                           style: TextStyle(
//                             fontSize: 22,
//                             fontWeight: FontWeight.w800,
//                             color: Colors.white,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const Spacer(),
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.end,
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 8,
//                             vertical: 4,
//                           ),
//                           decoration: BoxDecoration(
//                             color: const Color(0xFFF43F5E).withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: const Text(
//                             '2 Expiring',
//                             style: TextStyle(
//                               fontSize: 11,
//                               fontWeight: FontWeight.bold,
//                               color: Color(0xFFF43F5E),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         const Text(
//                           '3 Active',
//                           style: TextStyle(
//                             fontSize: 11,
//                             color: Color(0xFF10B981),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//         Expanded(
//           child: ListView.separated(
//             padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
//             itemCount: _subs.length,
//             separatorBuilder: (_, __) => const SizedBox(height: 10),
//             itemBuilder: (_, i) => _SubCard(data: _subs[i]),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _SubItem {
//   final String company, plan, status, renewDate, mrr;
//   final int seats;
//   final Color statusColor;
//   const _SubItem({
//     required this.company,
//     required this.plan,
//     required this.seats,
//     required this.status,
//     required this.renewDate,
//     required this.mrr,
//     required this.statusColor,
//   });
// }

// class _SubCard extends StatelessWidget {
//   final _SubItem data;
//   const _SubCard({required this.data});

//   Color get _planColor =>
//       data.plan == 'Enterprise'
//           ? const Color(0xFF6366F1)
//           : data.plan == 'Pro'
//           ? const Color(0xFF0EA5E9)
//           : const Color(0xFF64748B);

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: const Color(0xFF162032),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFF1E3050)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 40,
//                 height: 40,
//                 decoration: BoxDecoration(
//                   color: _planColor.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Icon(
//                   Icons.subscriptions_outlined,
//                   color: _planColor,
//                   size: 20,
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       data.company,
//                       style: const TextStyle(
//                         fontSize: 13,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                     const SizedBox(height: 3),
//                     Row(
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 6,
//                             vertical: 2,
//                           ),
//                           decoration: BoxDecoration(
//                             color: _planColor.withOpacity(0.1),
//                             borderRadius: BorderRadius.circular(5),
//                           ),
//                           child: Text(
//                             data.plan,
//                             style: TextStyle(
//                               fontSize: 9,
//                               fontWeight: FontWeight.w700,
//                               color: _planColor,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 6),
//                         Text(
//                           '${data.seats} seats',
//                           style: const TextStyle(
//                             fontSize: 10,
//                             color: Color(0xFF94A3B8),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 8,
//                       vertical: 3,
//                     ),
//                     decoration: BoxDecoration(
//                       color: data.statusColor.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                     child: Text(
//                       data.status,
//                       style: TextStyle(
//                         fontSize: 9,
//                         fontWeight: FontWeight.w700,
//                         color: data.statusColor,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     data.mrr,
//                     style: const TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//           const SizedBox(height: 10),
//           Container(height: 1, color: const Color(0xFF1E3050)),
//           const SizedBox(height: 10),
//           Row(
//             children: [
//               const Icon(
//                 Icons.calendar_today_outlined,
//                 size: 12,
//                 color: Color(0xFF64748B),
//               ),
//               const SizedBox(width: 5),
//               Text(
//                 'Renews: ${data.renewDate}',
//                 style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
//               ),
//               const Spacer(),
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 10,
//                   vertical: 5,
//                 ),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF6366F1).withOpacity(0.08),
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(
//                     color: const Color(0xFF6366F1).withOpacity(0.25),
//                   ),
//                 ),
//                 child: const Text(
//                   'View',
//                   style: TextStyle(
//                     fontSize: 11,
//                     fontWeight: FontWeight.w600,
//                     color: Color(0xFF6366F1),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// ─── Billing (Quick Action) ───────────────────────────────────────────────────

// class _BillingPage extends StatelessWidget {
//   const _BillingPage();

//   static const _invoices = [
//     _InvoiceItem(
//       id: 'INV-0041',
//       client: 'Acme Corp',
//       amount: '\$1,200.00',
//       date: 'Mar 01, 2026',
//       status: 'Paid',
//       statusColor: Color(0xFF10B981),
//     ),
//     _InvoiceItem(
//       id: 'INV-0040',
//       client: 'BlueSky Ltd.',
//       amount: '\$340.00',
//       date: 'Feb 28, 2026',
//       status: 'Overdue',
//       statusColor: Color(0xFFF43F5E),
//     ),
//     _InvoiceItem(
//       id: 'INV-0039',
//       client: 'NovaTech Inc.',
//       amount: '\$5,800.00',
//       date: 'Feb 26, 2026',
//       status: 'Paid',
//       statusColor: Color(0xFF10B981),
//     ),
//     _InvoiceItem(
//       id: 'INV-0038',
//       client: 'PixelWave Co.',
//       amount: '\$920.00',
//       date: 'Feb 25, 2026',
//       status: 'Pending',
//       statusColor: Color(0xFFF59E0B),
//     ),
//     _InvoiceItem(
//       id: 'INV-0037',
//       client: 'DataStream AI',
//       amount: '\$2,450.00',
//       date: 'Feb 22, 2026',
//       status: 'Paid',
//       statusColor: Color(0xFF10B981),
//     ),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
//           color: const Color(0xFF0F1923),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Billing',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//               ),
//               const SizedBox(height: 10),
//               Row(
//                 children: [
//                   Expanded(
//                     child: _BillStat(
//                       label: 'Total',
//                       value: '\$10,710',
//                       color: const Color(0xFF6366F1),
//                     ),
//                   ),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     child: _BillStat(
//                       label: 'Paid',
//                       value: '\$9,450',
//                       color: const Color(0xFF10B981),
//                     ),
//                   ),
//                   const SizedBox(width: 10),
//                   Expanded(
//                     child: _BillStat(
//                       label: 'Outstanding',
//                       value: '\$1,260',
//                       color: const Color(0xFFF43F5E),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//         Expanded(
//           child: ListView.separated(
//             padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
//             itemCount: _invoices.length,
//             separatorBuilder: (_, __) => const SizedBox(height: 10),
//             itemBuilder: (_, i) => _InvoiceCard(data: _invoices[i]),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _BillStat extends StatelessWidget {
//   final String label, value;
//   final Color color;
//   const _BillStat({
//     required this.label,
//     required this.value,
//     required this.color,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
//       decoration: BoxDecoration(
//         color: const Color(0xFF162032),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFF1E3050)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             value,
//             style: TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//               color: color,
//             ),
//           ),
//           const SizedBox(height: 2),
//           Text(
//             label,
//             style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _InvoiceItem {
//   final String id, client, amount, date, status;
//   final Color statusColor;
//   const _InvoiceItem({
//     required this.id,
//     required this.client,
//     required this.amount,
//     required this.date,
//     required this.status,
//     required this.statusColor,
//   });
// }

// class _InvoiceCard extends StatelessWidget {
//   final _InvoiceItem data;
//   const _InvoiceCard({required this.data});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: const Color(0xFF162032),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFF1E3050)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 40,
//             height: 40,
//             decoration: BoxDecoration(
//               color: const Color(0xFF6366F1).withOpacity(0.08),
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: const Icon(
//               Icons.description_outlined,
//               color: Color(0xFF6366F1),
//               size: 20,
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   data.client,
//                   style: const TextStyle(
//                     fontSize: 13,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//                 const SizedBox(height: 3),
//                 Row(
//                   children: [
//                     Text(
//                       data.id,
//                       style: const TextStyle(
//                         fontSize: 11,
//                         color: Color(0xFF64748B),
//                       ),
//                     ),
//                     const Text(
//                       ' · ',
//                       style: TextStyle(color: Color(0xFF64748B)),
//                     ),
//                     Text(
//                       data.date,
//                       style: const TextStyle(
//                         fontSize: 11,
//                         color: Color(0xFF64748B),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               Text(
//                 data.amount,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//                 decoration: BoxDecoration(
//                   color: data.statusColor.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//                 child: Text(
//                   data.status,
//                   style: TextStyle(
//                     fontSize: 9,
//                     fontWeight: FontWeight.w700,
//                     color: data.statusColor,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// ─── End Users (index 3) ──────────────────────────────────────────────────────

// class _EndUsersPage extends StatelessWidget {
//   const _EndUsersPage();

//   static const _users = [
//     _UserItem(
//       name: 'Lena Hartmann',
//       company: 'Acme Corp',
//       plan: 'Enterprise',
//       tickets: 3,
//       initials: 'LH',
//       color: Color(0xFF6366F1),
//     ),
//     _UserItem(
//       name: 'Carlos Mendes',
//       company: 'BlueSky Ltd.',
//       plan: 'Pro',
//       tickets: 1,
//       initials: 'CM',
//       color: Color(0xFF10B981),
//     ),
//     _UserItem(
//       name: 'Aisha Patel',
//       company: 'NovaTech Inc.',
//       plan: 'Enterprise',
//       tickets: 2,
//       initials: 'AP',
//       color: Color(0xFFF59E0B),
//     ),
//     _UserItem(
//       name: 'Tom Nguyen',
//       company: 'PixelWave Co.',
//       plan: 'Starter',
//       tickets: 0,
//       initials: 'TN',
//       color: Color(0xFF64748B),
//     ),
//     _UserItem(
//       name: 'Sofia Rossi',
//       company: 'DataStream AI',
//       plan: 'Pro',
//       tickets: 1,
//       initials: 'SR',
//       color: Color(0xFF0EA5E9),
//     ),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
//           color: const Color(0xFF0F1923),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'End Users',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//               ),
//               const SizedBox(height: 10),
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 14,
//                   vertical: 10,
//                 ),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF162032),
//                   borderRadius: BorderRadius.circular(12),
//                   border: Border.all(color: const Color(0xFF1E3050)),
//                 ),
//                 child: Row(
//                   children: const [
//                     Icon(Icons.search, color: Color(0xFF64748B), size: 18),
//                     SizedBox(width: 10),
//                     Text(
//                       'Search users...',
//                       style: TextStyle(color: Color(0xFF4A5568), fontSize: 13),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 6),
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 10,
//                   vertical: 6,
//                 ),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF162032),
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: const Color(0xFF1E3050)),
//                 ),
//                 child: Row(
//                   children: const [
//                     Icon(
//                       Icons.info_outline,
//                       color: Color(0xFF64748B),
//                       size: 13,
//                     ),
//                     SizedBox(width: 6),
//                     Text(
//                       'You can view end users and create tickets on their behalf.',
//                       style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//         Expanded(
//           child: ListView.separated(
//             padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
//             itemCount: _users.length,
//             separatorBuilder: (_, __) => const SizedBox(height: 10),
//             itemBuilder: (_, i) => _UserCard(data: _users[i]),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _UserItem {
//   final String name, company, plan, initials;
//   final int tickets;
//   final Color color;
//   const _UserItem({
//     required this.name,
//     required this.company,
//     required this.plan,
//     required this.tickets,
//     required this.initials,
//     required this.color,
//   });
// }

// class _UserCard extends StatelessWidget {
//   final _UserItem data;
//   const _UserCard({required this.data});

//   Color get _planColor =>
//       data.plan == 'Enterprise'
//           ? const Color(0xFF6366F1)
//           : data.plan == 'Pro'
//           ? const Color(0xFF0EA5E9)
//           : const Color(0xFF64748B);

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: const Color(0xFF162032),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFF1E3050)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 44,
//             height: 44,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: data.color.withOpacity(0.12),
//               border: Border.all(color: data.color.withOpacity(0.3)),
//             ),
//             child: Center(
//               child: Text(
//                 data.initials,
//                 style: TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.bold,
//                   color: data.color,
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   data.name,
//                   style: const TextStyle(
//                     fontSize: 13,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   data.company,
//                   style: const TextStyle(
//                     fontSize: 11,
//                     color: Color(0xFF64748B),
//                   ),
//                 ),
//                 const SizedBox(height: 5),
//                 Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 6,
//                         vertical: 2,
//                       ),
//                       decoration: BoxDecoration(
//                         color: _planColor.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(5),
//                       ),
//                       child: Text(
//                         data.plan,
//                         style: TextStyle(
//                           fontSize: 9,
//                           fontWeight: FontWeight.w700,
//                           color: _planColor,
//                         ),
//                       ),
//                     ),
//                     if (data.tickets > 0) ...[
//                       const SizedBox(width: 6),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 6,
//                           vertical: 2,
//                         ),
//                         decoration: BoxDecoration(
//                           color: const Color(0xFFF59E0B).withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(5),
//                         ),
//                         child: Text(
//                           '${data.tickets} open ticket${data.tickets > 1 ? 's' : ''}',
//                           style: const TextStyle(
//                             fontSize: 9,
//                             fontWeight: FontWeight.w700,
//                             color: Color(0xFFF59E0B),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           GestureDetector(
//             onTap: () {},
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
//               decoration: BoxDecoration(
//                 color: const Color(0xFF6366F1).withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(
//                   color: const Color(0xFF6366F1).withOpacity(0.3),
//                 ),
//               ),
//               child: const Text(
//                 '+ Ticket',
//                 style: TextStyle(
//                   fontSize: 11,
//                   fontWeight: FontWeight.w700,
//                   color: Color(0xFF6366F1),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// ─── Settings (index 4) ───────────────────────────────────────────────────────

class _AgentSettingsPage extends StatelessWidget {
  const _AgentSettingsPage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F1923),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1060), Color(0xFF162032)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'JD',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'James Davis',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'james.davis@support.io',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Support Agent · Level 2',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'ACCOUNT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.person_outline,
            label: 'Edit Profile',
            subtitle: 'Update your name, photo and info',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AgentEditProfilePage()),
              );
            },
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.lock_outline,
            label: 'Change Password',
            subtitle: 'Update your account password',
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            label: 'Manage User',
            subtitle: 'Manage user access and permissions',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AgentManageUsersPage()),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'SUPPORT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.menu_book_outlined,
            label: 'User Guide',
            subtitle: 'Tips and best practices',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AgentUserGuidePage()),
              );
            },
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.help_outline,
            label: 'Help & FAQ',
            subtitle: 'Get help with the portal',
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFEF4444).withOpacity(0.35),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.logout, color: Color(0xFFEF4444), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Logout',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final VoidCallback? onTap; // ✅ ADD THIS

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF162032),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E3050)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
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
            const Icon(Icons.chevron_right, color: Color(0xFF64748B), size: 20),
          ],
        ),
      ),
    );
  }
}
