import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);

class AdminUserGuidePage extends StatefulWidget {
  const AdminUserGuidePage({super.key});

  @override
  State<AdminUserGuidePage> createState() => _AdminUserGuidePageState();
}

class _AdminUserGuidePageState extends State<AdminUserGuidePage>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _expandedIndex;
  late AnimationController _listAnim;

  final List<Map<String, dynamic>> _guideItems = [
    {
      'title': 'Getting Started',
      'icon': Icons.rocket_launch_outlined,
      'color': const Color(0xFF0F62FE),
      'content':
          'Welcome to the Admin Panel! Use the bottom navigation bar to switch between sections: Dashboard, Agents, Quick Actions, End Users, and Settings.\n\nThe red Quick Action button in the center gives you fast access to Tickets, Subscriptions, and Billing.',
    },
    {
      'title': 'Managing Subscriptions',
      'icon': Icons.subscriptions_outlined,
      'color': const Color(0xFF6929C4),
      'content':
          'The Subscriptions section lists all customer plans. Each card shows the plan name, assigned user, renewal date, and current status.\n\nTap a subscription to view detailed billing cycle data and Starlink service line information.',
    },
    {
      'title': 'Handling Tickets',
      'icon': Icons.confirmation_number_outlined,
      'color': const Color(0xFFFF832B),
      'content':
          'Tickets are organized by status: Open, In Progress, Resolved, and Closed. The dashboard shows a real-time ticket overview with color-coded counts.\n\nTap any ticket in Recent Activity to view its full details, attachments, and activity log.',
    },
    {
      'title': 'Billing & Invoices',
      'icon': Icons.receipt_long_outlined,
      'color': const Color(0xFF24A148),
      'content':
          'The Billing section displays revenue summaries and individual invoices. Invoices can be Paid, Pending, or Overdue.\n\nMonitor overdue invoices promptly to maintain healthy cash flow.',
    },
    {
      'title': 'Managing Agents',
      'icon': Icons.group_outlined,
      'color': const Color(0xFF007D79),
      'content':
          'Agents are your support staff. Each agent card shows their status, assigned tickets, and contact details.\n\nUse the agent detail view to see their full subscription and ticket history.',
    },
    {
      'title': 'Managing End Users',
      'icon': Icons.people_alt_outlined,
      'color': const Color(0xFF1192E8),
      'content':
          'End Users are your customers. The End Users page supports search and pagination.\n\nTap a user card to see their details, linked subscriptions, and account status.',
    },
    {
      'title': 'User Roles & Permissions',
      'icon': Icons.security_outlined,
      'color': _primary,
      'content':
          'Roles define what a user can do:\n\n• Admin – Full access to all sections\n• Agent – Can view and manage tickets and end users\n• User – Standard account access\n\nChange roles from Manage Users in the Settings tab.',
    },
    {
      'title': 'Account & Security',
      'icon': Icons.lock_outline,
      'color': const Color(0xFFEB1E23),
      'content':
          'Update your profile details, change your password, and enable Two-Factor Authentication from the Edit Profile page.\n\nEmail notifications can also be toggled from that screen.',
    },
  ];

  List<Map<String, dynamic>> get _filtered =>
      _guideItems.where((item) {
        final q = _searchQuery.toLowerCase();
        return (item['title'] as String).toLowerCase().contains(q) ||
            (item['content'] as String).toLowerCase().contains(q);
      }).toList();

  @override
  void initState() {
    super.initState();
    _listAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _listAnim.forward());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _surfaceSubtle,
        body: Column(
          children: [
            // ── Gradient AppBar ────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEB1E23), Color(0xFF760F12)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // Back button row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'User Guide',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  'Tips and documentation for admins',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_guideItems.length} topics',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search bar inside the header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          onChanged:
                              (val) => setState(() {
                                _searchQuery = val;
                                _expandedIndex = null;
                              }),
                          decoration: InputDecoration(
                            hintText: 'Search guide topics...',
                            hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 13,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.white.withOpacity(0.7),
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Guide List ─────────────────────────────────────────────────
            Expanded(
              child:
                  _filtered.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.search_off_outlined,
                                color: _primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'No topics found',
                              style: TextStyle(
                                color: _inkSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Try a different search term',
                              style: TextStyle(
                                color: _inkTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _filtered[index];
                          final isExpanded = _expandedIndex == index;
                          final delay = index * 0.07;

                          return AnimatedBuilder(
                            animation: _listAnim,
                            builder: (context, child) {
                              final t = (_listAnim.value - delay).clamp(
                                0.0,
                                1.0,
                              );
                              return Opacity(
                                opacity: t,
                                child: Transform.translate(
                                  offset: Offset(0, 16 * (1 - t)),
                                  child: child,
                                ),
                              );
                            },
                            child: _GuideCard(
                              title: item['title'] as String,
                              icon: item['icon'] as IconData,
                              color: item['color'] as Color,
                              content: item['content'] as String,
                              isExpanded: isExpanded,
                              onTap:
                                  () => setState(() {
                                    _expandedIndex = isExpanded ? null : index;
                                  }),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Guide Card with animated expand ──────────────────────────────────────────

class _GuideCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String content;
  final bool isExpanded;
  final VoidCallback onTap;

  const _GuideCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.content,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  State<_GuideCard> createState() => _GuideCardState();
}

class _GuideCardState extends State<_GuideCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    if (widget.isExpanded) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_GuideCard old) {
    super.didUpdateWidget(old);
    if (widget.isExpanded != old.isExpanded) {
      if (widget.isExpanded) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  widget.isExpanded ? widget.color.withOpacity(0.35) : _border,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    widget.isExpanded
                        ? widget.color.withOpacity(0.1)
                        : Colors.black.withOpacity(0.03),
                blurRadius: widget.isExpanded ? 16 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          widget.isExpanded
                              ? widget.color
                              : widget.color.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow:
                          widget.isExpanded
                              ? [
                                BoxShadow(
                                  color: widget.color.withOpacity(0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                              : [],
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.isExpanded ? Colors.white : widget.color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: widget.isExpanded ? widget.color : _ink,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: widget.isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color:
                            widget.isExpanded
                                ? widget.color.withOpacity(0.1)
                                : _surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: widget.isExpanded ? widget.color : _inkTertiary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              FadeTransition(
                opacity: _fade,
                child: SizeTransition(
                  sizeFactor: _ctrl,
                  axisAlignment: -1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),
                      Container(height: 1, color: _border),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 3,
                            margin: const EdgeInsets.only(right: 12, top: 2),
                            decoration: BoxDecoration(
                              color: widget.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              widget.content,
                              style: const TextStyle(fontSize: 0),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.content,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.65,
                                color: _inkSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
