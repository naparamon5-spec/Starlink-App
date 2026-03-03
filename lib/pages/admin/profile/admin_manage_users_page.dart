import 'package:flutter/material.dart';

class AdminManageUsersPage extends StatefulWidget {
  const AdminManageUsersPage({super.key});

  @override
  State<AdminManageUsersPage> createState() => _AdminManageUsersPageState();
}

class _AdminManageUsersPageState extends State<AdminManageUsersPage> {
  final List<Map<String, dynamic>> _users = [
    {
      'name': 'Michael Scott',
      'email': 'michael@company.com',
      'role': 'Admin',
      'status': 'Active',
      'avatar': 'MS',
    },
    {
      'name': 'Dwight Schrute',
      'email': 'dwight@company.com',
      'role': 'Agent',
      'status': 'Active',
      'avatar': 'DS',
    },
    {
      'name': 'Jim Halpert',
      'email': 'jim@company.com',
      'role': 'Agent',
      'status': 'Active',
      'avatar': 'JH',
    },
    {
      'name': 'Pam Beesly',
      'email': 'pam@company.com',
      'role': 'Viewer',
      'status': 'Inactive',
      'avatar': 'PB',
    },
  ];

  void _showEditRoleDialog(int index) {
    String selectedRole = _users[index]['role'];
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Role – ${_users[index]['name']}'),
            content: StatefulBuilder(
              builder:
                  (context, setDialogState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        ['Admin', 'Agent', 'Viewer']
                            .map(
                              (role) => RadioListTile<String>(
                                title: Text(role),
                                value: role,
                                groupValue: selectedRole,
                                activeColor: const Color(0xFF133343),
                                onChanged:
                                    (val) => setDialogState(
                                      () => selectedRole = val!,
                                    ),
                              ),
                            )
                            .toList(),
                  ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF133343),
                ),
                onPressed: () {
                  setState(() => _users[index]['role'] = selectedRole);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Save',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _toggleStatus(int index) {
    setState(() {
      _users[index]['status'] =
          _users[index]['status'] == 'Active' ? 'Inactive' : 'Active';
    });
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add New User'),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF133343),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Admin':
        return const Color(0xFF133343);
      case 'Agent':
        return Colors.purple;
      case 'Viewer':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Users',
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        backgroundColor: const Color(0xFF133343),
        child: const Icon(Icons.person_add_outlined, color: Colors.white),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final user = _users[index];
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
                  Text(user['email'], style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _roleColor(user['role']).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user['role'],
                      style: TextStyle(
                        color: _roleColor(user['role']),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: user['status'] == 'Active',
                    activeColor: const Color(0xFF133343),
                    onChanged: (_) => _toggleStatus(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _showEditRoleDialog(index),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
