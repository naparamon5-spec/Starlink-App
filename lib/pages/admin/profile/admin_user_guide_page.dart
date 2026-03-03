import 'package:flutter/material.dart';

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
      'color': const Color(0xFF133343),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Guide',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF133343),
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged:
                  (val) => setState(() {
                    _searchQuery = val;
                    _expandedIndex = null;
                  }),
              decoration: InputDecoration(
                hintText: 'Search guide topics...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
              ),
            ),
          ),
          Expanded(
            child:
                _filtered.isEmpty
                    ? const Center(
                      child: Text(
                        'No topics found.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _filtered[index];
                        final isExpanded = _expandedIndex == index;
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap:
                                () => setState(
                                  () =>
                                      _expandedIndex =
                                          isExpanded ? null : index,
                                ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: (item['color']
                                                as Color)
                                            .withOpacity(0.15),
                                        child: Icon(
                                          item['icon'] as IconData,
                                          color: item['color'] as Color,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          item['title'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        isExpanded
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                  if (isExpanded) ...[
                                    const SizedBox(height: 12),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    Text(
                                      item['content'],
                                      style: const TextStyle(
                                        height: 1.5,
                                        color: Colors.black87,
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
    );
  }
}
