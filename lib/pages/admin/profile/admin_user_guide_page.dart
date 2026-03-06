import 'package:flutter/material.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFF0F62FE);
const _ink = Color(0xFF161616);
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

class _AdminUserGuidePageState extends State<AdminUserGuidePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _expandedIndex;

  final List<Map<String, dynamic>> _guideItems = [
    {
      'title': 'Getting Started',
      'icon': Icons.rocket_launch_outlined,
      'color': Colors.blue,
      'content':
          'Welcome to the Admin Panel! Use the bottom navigation bar to switch between sections: Dashboard, Subscriptions, Tickets, Billing, Agents, and End Users.\n\nThe top-right menu gives you quick access to Manage Users, Edit Profile, and this User Guide.',
    },
    {
      'title': 'Managing Subscriptions',
      'icon': Icons.subscriptions_outlined,
      'color': Colors.purple,
      'content':
          'The Subscriptions section lists all customer plans. You can filter by status (Active, Expired, Cancelled).\n\nEach card shows the plan name, assigned user, renewal date, price, and current status.',
    },
    {
      'title': 'Handling Tickets',
      'icon': Icons.confirmation_number_outlined,
      'color': Colors.orange,
      'content':
          'Tickets are organized by status tabs: Open, In Progress, and Closed. Each ticket shows priority (High, Medium, Low) along with the submitting user and date.\n\nAssign tickets to agents and update their status as work progresses.',
    },
    {
      'title': 'Billing & Invoices',
      'icon': Icons.receipt_long_outlined,
      'color': Colors.green,
      'content':
          'The Billing page displays revenue summaries and individual invoices. Invoices can be Paid, Pending, or Overdue.\n\nMonitor overdue invoices promptly to maintain cash flow.',
    },
    {
      'title': 'Managing Agents',
      'icon': Icons.group_outlined,
      'color': Colors.teal,
      'content':
          'Agents are your support staff. Each agent has a status indicator: Online (green), Busy (orange), or Offline (grey).\n\nUse the "+" button to add new agents. You can view how many tickets each agent currently holds.',
    },
    {
      'title': 'Managing End Users',
      'icon': Icons.people_alt_outlined,
      'color': Colors.indigo,
      'content':
          'End Users are your customers. Tap any user card to see their details, subscription plan, and account status.\n\nYou can suspend or contact users directly from the detail sheet.',
    },
    {
      'title': 'User Roles & Permissions',
      'icon': Icons.security_outlined,
      'color': _primary,
      'content':
          'Roles define what a user can do:\n\n• Admin – Full access to all sections\n• Agent – Can view and manage tickets and end users\n• Viewer – Read-only access\n\nChange roles via Manage Users in the top-right profile menu.',
    },
    {
      'title': 'Account & Security',
      'icon': Icons.lock_outline,
      'color': Colors.red,
      'content':
          'Update your profile details, change your password, and enable Two-Factor Authentication from the Edit Profile page.\n\nEmail notifications can also be toggled from that screen.',
    },
  ];

  List<Map<String, dynamic>> get _filtered =>
      _guideItems
          .where(
            (item) =>
                item['title'].toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                item['content'].toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
          )
          .toList();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceSubtle,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────
            Container(
              color: _surface,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'User Guide',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Search
                  Container(
                    decoration: BoxDecoration(
                      color: _surfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          _expandedIndex = null;
                        });
                      },
                      style: const TextStyle(fontSize: 13, color: _ink),
                      decoration: const InputDecoration(
                        hintText: 'Search guide topics...',
                        hintStyle: TextStyle(color: _inkTertiary, fontSize: 13),
                        prefixIcon: Icon(
                          Icons.search,
                          color: _inkTertiary,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(height: 1, color: _border),

            // ── Guide List ─────────────────────────────────────────
            Expanded(
              child:
                  _filtered.isEmpty
                      ? const Center(
                        child: Text(
                          'No topics found',
                          style: TextStyle(color: _inkSecondary, fontSize: 13),
                        ),
                      )
                      : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _filtered[index];
                          final isExpanded = _expandedIndex == index;

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                setState(() {
                                  _expandedIndex = isExpanded ? null : index;
                                });
                              },
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: (item['color'] as Color)
                                                .withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            item['icon'],
                                            color: item['color'],
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            item['title'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: _ink,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          isExpanded
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          color: _inkTertiary,
                                        ),
                                      ],
                                    ),

                                    if (isExpanded) ...[
                                      const SizedBox(height: 12),
                                      Container(height: 1, color: _border),
                                      const SizedBox(height: 10),
                                      Text(
                                        item['content'],
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.6,
                                          color: _inkSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
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
