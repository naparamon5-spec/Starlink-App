import 'package:flutter/material.dart';

class AdminSubscriptionsPage extends StatefulWidget {
  const AdminSubscriptionsPage({super.key});

  @override
  State<AdminSubscriptionsPage> createState() => _AdminSubscriptionsPageState();
}

class _AdminSubscriptionsPageState extends State<AdminSubscriptionsPage> {
  final List<Map<String, dynamic>> _subscriptions = [
    {
      'id': 'SUB-001',
      'name': 'Basic Plan',
      'user': 'John Doe',
      'status': 'Active',
      'price': '\$9.99/mo',
      'renewalDate': 'Apr 1, 2025',
    },
    {
      'id': 'SUB-002',
      'name': 'Pro Plan',
      'user': 'Jane Smith',
      'status': 'Active',
      'price': '\$29.99/mo',
      'renewalDate': 'Apr 15, 2025',
    },
    {
      'id': 'SUB-003',
      'name': 'Enterprise Plan',
      'user': 'Acme Corp',
      'status': 'Expired',
      'price': '\$99.99/mo',
      'renewalDate': 'Mar 1, 2025',
    },
    {
      'id': 'SUB-004',
      'name': 'Basic Plan',
      'user': 'Bob Johnson',
      'status': 'Cancelled',
      'price': '\$9.99/mo',
      'renewalDate': 'N/A',
    },
    {
      'id': 'SUB-005',
      'name': 'Pro Plan',
      'user': 'Alice Brown',
      'status': 'Active',
      'price': '\$29.99/mo',
      'renewalDate': 'May 5, 2025',
    },
  ];

  String _filterStatus = 'All';

  List<Map<String, dynamic>> get _filtered {
    if (_filterStatus == 'All') return _subscriptions;
    return _subscriptions.where((s) => s['status'] == _filterStatus).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Expired':
        return Colors.orange;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'Filter: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _filterStatus,
                items:
                    ['All', 'Active', 'Expired', 'Cancelled']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                onChanged: (val) => setState(() => _filterStatus = val!),
              ),
              const Spacer(),
              Text(
                '${_filtered.length} results',
                style: const TextStyle(color: Colors.grey),
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
              final sub = _filtered[index];
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
                    backgroundColor: const Color(0xFF133343),
                    child: Text(
                      sub['name'][0],
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    sub['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('User: ${sub['user']}'),
                      Text('Renewal: ${sub['renewalDate']}'),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        sub['price'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(sub['status']).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          sub['status'],
                          style: TextStyle(
                            color: _statusColor(sub['status']),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
