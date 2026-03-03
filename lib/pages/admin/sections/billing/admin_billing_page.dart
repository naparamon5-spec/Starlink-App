import 'package:flutter/material.dart';

class AdminBillingPage extends StatelessWidget {
  const AdminBillingPage({super.key});

  final List<Map<String, dynamic>> _invoices = const [
    {
      'id': 'INV-2025-001',
      'user': 'John Doe',
      'amount': '\$9.99',
      'date': 'Mar 1, 2025',
      'status': 'Paid',
      'plan': 'Basic Plan',
    },
    {
      'id': 'INV-2025-002',
      'user': 'Jane Smith',
      'amount': '\$29.99',
      'date': 'Mar 5, 2025',
      'status': 'Paid',
      'plan': 'Pro Plan',
    },
    {
      'id': 'INV-2025-003',
      'user': 'Acme Corp',
      'amount': '\$99.99',
      'date': 'Mar 8, 2025',
      'status': 'Overdue',
      'plan': 'Enterprise Plan',
    },
    {
      'id': 'INV-2025-004',
      'user': 'Bob Johnson',
      'amount': '\$9.99',
      'date': 'Mar 12, 2025',
      'status': 'Pending',
      'plan': 'Basic Plan',
    },
    {
      'id': 'INV-2025-005',
      'user': 'Alice Brown',
      'amount': '\$29.99',
      'date': 'Mar 15, 2025',
      'status': 'Paid',
      'plan': 'Pro Plan',
    },
  ];

  Color _statusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Overdue':
        return Colors.red;
      case 'Pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalRevenue = _invoices
        .where((i) => i['status'] == 'Paid')
        .fold<double>(0, (sum, i) {
          final amount = double.parse(i['amount'].replaceAll('\$', ''));
          return sum + amount;
        });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Total Revenue',
                  value: '\$${totalRevenue.toStringAsFixed(2)}',
                  icon: Icons.attach_money,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  title: 'Overdue',
                  value:
                      '${_invoices.where((i) => i['status'] == 'Overdue').length}',
                  icon: Icons.warning_amber_outlined,
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  title: 'Pending',
                  value:
                      '${_invoices.where((i) => i['status'] == 'Pending').length}',
                  icon: Icons.hourglass_empty_outlined,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Recent Invoices',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _invoices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final invoice = _invoices[index];
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
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    invoice['id'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(invoice['user']),
                      Text(
                        invoice['plan'],
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
                        invoice['amount'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
                            invoice['status'],
                          ).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          invoice['status'],
                          style: TextStyle(
                            color: _statusColor(invoice['status']),
                            fontSize: 11,
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
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
