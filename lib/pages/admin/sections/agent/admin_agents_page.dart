import 'package:flutter/material.dart';

class AdminAgentsPage extends StatefulWidget {
  const AdminAgentsPage({super.key});

  @override
  State<AdminAgentsPage> createState() => _AdminAgentsPageState();
}

class _AdminAgentsPageState extends State<AdminAgentsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _agents = [
    {
      'name': 'Michael Scott',
      'email': 'michael@company.com',
      'role': 'Senior Agent',
      'status': 'Online',
      'tickets': 12,
      'avatar': 'MS',
    },
    {
      'name': 'Dwight Schrute',
      'email': 'dwight@company.com',
      'role': 'Agent',
      'status': 'Busy',
      'tickets': 8,
      'avatar': 'DS',
    },
    {
      'name': 'Jim Halpert',
      'email': 'jim@company.com',
      'role': 'Agent',
      'status': 'Offline',
      'tickets': 5,
      'avatar': 'JH',
    },
    {
      'name': 'Pam Beesly',
      'email': 'pam@company.com',
      'role': 'Junior Agent',
      'status': 'Online',
      'tickets': 3,
      'avatar': 'PB',
    },
    {
      'name': 'Kevin Malone',
      'email': 'kevin@company.com',
      'role': 'Junior Agent',
      'status': 'Offline',
      'tickets': 2,
      'avatar': 'KM',
    },
  ];

  List<Map<String, dynamic>> get _filtered =>
      _agents
          .where(
            (a) =>
                a['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
                a['email'].toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();

  Color _statusColor(String status) {
    switch (status) {
      case 'Online':
        return Colors.green;
      case 'Busy':
        return Colors.orange;
      case 'Offline':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _showAddAgentDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New Agent'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 8),
                TextField(decoration: const InputDecoration(labelText: 'Role')),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF133343),
                ),
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search agents...',
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
              const SizedBox(width: 12),
              FloatingActionButton.small(
                onPressed: _showAddAgentDialog,
                backgroundColor: const Color(0xFF133343),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final agent = _filtered[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF133343),
                        child: Text(
                          agent['avatar'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _statusColor(agent['status']),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    agent['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent['email'],
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        agent['role'],
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${agent['tickets']} tickets',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        agent['status'],
                        style: TextStyle(
                          color: _statusColor(agent['status']),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
