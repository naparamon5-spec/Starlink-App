import 'package:flutter/material.dart';

class AdminEndUsersPage extends StatefulWidget {
  const AdminEndUsersPage({super.key});

  @override
  State<AdminEndUsersPage> createState() => _AdminEndUsersPageState();
}

class _AdminEndUsersPageState extends State<AdminEndUsersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _users = [
    {
      'name': 'John Doe',
      'email': 'john.doe@email.com',
      'plan': 'Basic',
      'status': 'Active',
      'joined': 'Jan 10, 2025',
      'avatar': 'JD',
    },
    {
      'name': 'Jane Smith',
      'email': 'jane.smith@email.com',
      'plan': 'Pro',
      'status': 'Active',
      'joined': 'Feb 3, 2025',
      'avatar': 'JS',
    },
    {
      'name': 'Bob Johnson',
      'email': 'bob.j@email.com',
      'plan': 'Basic',
      'status': 'Suspended',
      'joined': 'Dec 15, 2024',
      'avatar': 'BJ',
    },
    {
      'name': 'Alice Brown',
      'email': 'alice.b@email.com',
      'plan': 'Pro',
      'status': 'Active',
      'joined': 'Mar 1, 2025',
      'avatar': 'AB',
    },
    {
      'name': 'Charlie Wilson',
      'email': 'charlie.w@email.com',
      'plan': 'Enterprise',
      'status': 'Active',
      'joined': 'Nov 20, 2024',
      'avatar': 'CW',
    },
    {
      'name': 'Diana Prince',
      'email': 'diana.p@email.com',
      'plan': 'Basic',
      'status': 'Inactive',
      'joined': 'Oct 5, 2024',
      'avatar': 'DP',
    },
  ];

  List<Map<String, dynamic>> get _filtered =>
      _users
          .where(
            (u) =>
                u['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
                u['email'].toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();

  Color _statusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Suspended':
        return Colors.red;
      case 'Inactive':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _planColor(String plan) {
    switch (plan) {
      case 'Enterprise':
        return const Color(0xFF133343);
      case 'Pro':
        return Colors.purple;
      case 'Basic':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFF133343),
                  child: Text(
                    user['avatar'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user['name'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(user['email'], style: const TextStyle(color: Colors.grey)),
                const Divider(height: 24),
                _InfoRow(label: 'Plan', value: user['plan']),
                _InfoRow(label: 'Status', value: user['status']),
                _InfoRow(label: 'Joined', value: user['joined']),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.block, size: 16),
                        label: const Text('Suspend'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.message_outlined, size: 16),
                        label: const Text('Contact'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF133343),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search end users...',
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${_filtered.length} users',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final user = _filtered[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () => _showUserDetails(user),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF133343),
                      child: Text(
                        user['avatar'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      user['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['email'],
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Joined: ${user['joined']}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
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
                            color: _planColor(user['plan']).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            user['plan'],
                            style: TextStyle(
                              color: _planColor(user['plan']),
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
                            color: _statusColor(
                              user['status'],
                            ).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            user['status'],
                            style: TextStyle(
                              color: _statusColor(user['status']),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
