import 'package:flutter/material.dart';

class AdminTicketsPage extends StatefulWidget {
  const AdminTicketsPage({super.key});

  @override
  State<AdminTicketsPage> createState() => _AdminTicketsPageState();
}

class _AdminTicketsPageState extends State<AdminTicketsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _tickets = [
    {
      'id': 'TKT-101',
      'subject': 'Cannot login to account',
      'user': 'John Doe',
      'priority': 'High',
      'status': 'Open',
      'date': 'Mar 20, 2025',
    },
    {
      'id': 'TKT-102',
      'subject': 'Billing issue with invoice',
      'user': 'Jane Smith',
      'priority': 'Medium',
      'status': 'In Progress',
      'date': 'Mar 19, 2025',
    },
    {
      'id': 'TKT-103',
      'subject': 'Feature request: export to PDF',
      'user': 'Bob Johnson',
      'priority': 'Low',
      'status': 'Closed',
      'date': 'Mar 15, 2025',
    },
    {
      'id': 'TKT-104',
      'subject': 'App crashes on startup',
      'user': 'Alice Brown',
      'priority': 'High',
      'status': 'Open',
      'date': 'Mar 21, 2025',
    },
    {
      'id': 'TKT-105',
      'subject': 'Slow performance on dashboard',
      'user': 'Acme Corp',
      'priority': 'Medium',
      'status': 'In Progress',
      'date': 'Mar 18, 2025',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _ticketsByStatus(String status) {
    if (status == 'All') return _tickets;
    return _tickets.where((t) => t['status'] == status).toList();
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Open':
        return Colors.green;
      case 'In Progress':
        return Colors.orange;
      case 'Closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _ticketList(List<Map<String, dynamic>> tickets) {
    if (tickets.isEmpty) {
      return const Center(child: Text('No tickets found.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final ticket = tickets[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            leading: CircleAvatar(
              backgroundColor: _priorityColor(ticket['priority']),
              child: const Icon(
                Icons.confirmation_number_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              ticket['subject'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${ticket['id']} • ${ticket['user']}'),
                Text(
                  ticket['date'],
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(ticket['status']).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    ticket['status'],
                    style: TextStyle(
                      color: _statusColor(ticket['status']),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _priorityColor(ticket['priority']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    ticket['priority'],
                    style: TextStyle(
                      color: _priorityColor(ticket['priority']),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF133343),
          indicatorColor: const Color(0xFF133343),
          tabs: const [
            Tab(text: 'Open'),
            Tab(text: 'In Progress'),
            Tab(text: 'Closed'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _ticketList(_ticketsByStatus('Open')),
              _ticketList(_ticketsByStatus('In Progress')),
              _ticketList(_ticketsByStatus('Closed')),
            ],
          ),
        ),
      ],
    );
  }
}
