import 'package:flutter/material.dart';
import 'dart:math' as math;

// ─── Billing (Quick Action) ───────────────────────────────────────────────────

class BillingPage extends StatelessWidget {
  const BillingPage();

  static const _invoices = [
    InvoiceItem(
      id: 'INV-0041',
      client: 'Acme Corp',
      amount: '\$1,200.00',
      date: 'Mar 01, 2026',
      status: 'Paid',
      statusColor: Color(0xFF10B981),
    ),
    InvoiceItem(
      id: 'INV-0040',
      client: 'BlueSky Ltd.',
      amount: '\$340.00',
      date: 'Feb 28, 2026',
      status: 'Overdue',
      statusColor: Color(0xFFF43F5E),
    ),
    InvoiceItem(
      id: 'INV-0039',
      client: 'NovaTech Inc.',
      amount: '\$5,800.00',
      date: 'Feb 26, 2026',
      status: 'Paid',
      statusColor: Color(0xFF10B981),
    ),
    InvoiceItem(
      id: 'INV-0038',
      client: 'PixelWave Co.',
      amount: '\$920.00',
      date: 'Feb 25, 2026',
      status: 'Pending',
      statusColor: Color(0xFFF59E0B),
    ),
    InvoiceItem(
      id: 'INV-0037',
      client: 'DataStream AI',
      amount: '\$2,450.00',
      date: 'Feb 22, 2026',
      status: 'Paid',
      statusColor: Color(0xFF10B981),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          color: const Color(0xFF0F1923),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Billing',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: BillStat(
                      label: 'Total',
                      value: '\$10,710',
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BillStat(
                      label: 'Paid',
                      value: '\$9,450',
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BillStat(
                      label: 'Outstanding',
                      value: '\$1,260',
                      color: const Color(0xFFF43F5E),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemCount: _invoices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => InvoiceCard(data: _invoices[i]),
          ),
        ),
      ],
    );
  }
}

class BillStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const BillStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF162032),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3050)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class InvoiceItem {
  final String id, client, amount, date, status;
  final Color statusColor;
  const InvoiceItem({
    required this.id,
    required this.client,
    required this.amount,
    required this.date,
    required this.status,
    required this.statusColor,
  });
}

class InvoiceCard extends StatelessWidget {
  final InvoiceItem data;
  const InvoiceCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF162032),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3050)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Color(0xFF6366F1),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.client,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      data.id,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const Text(
                      ' · ',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                    Text(
                      data.date,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data.amount,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: data.statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.status,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: data.statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
