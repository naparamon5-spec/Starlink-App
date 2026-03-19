import 'package:flutter/material.dart';

// ─── Billing Tab ──────────────────────────────────────────────────────────────

class BillingTab extends StatefulWidget {
  const BillingTab({super.key});

  @override
  State<BillingTab> createState() => BillingTabState();
}

class BillingTabState extends State<BillingTab> {
  int _filterIndex = 0;
  final _filters = ['All', 'Paid', 'Pending', 'Overdue', 'Draft'];

  final _invoices = const [
    InvoiceData(
      id: 'INV-0041',
      client: 'Acme Corp',
      amount: '\$1,200.00',
      date: 'Mar 01, 2026',
      status: 'Paid',
      statusColor: Color(0xFF00D4AA),
    ),
    InvoiceData(
      id: 'INV-0040',
      client: 'BlueSky Ltd.',
      amount: '\$340.00',
      date: 'Feb 28, 2026',
      status: 'Overdue',
      statusColor: Color(0xFFFF6B35),
    ),
    InvoiceData(
      id: 'INV-0039',
      client: 'NovaTech Inc.',
      amount: '\$5,800.00',
      date: 'Feb 26, 2026',
      status: 'Paid',
      statusColor: Color(0xFF00D4AA),
    ),
    InvoiceData(
      id: 'INV-0038',
      client: 'PixelWave Co.',
      amount: '\$920.00',
      date: 'Feb 25, 2026',
      status: 'Pending',
      statusColor: Color(0xFFFFA500),
    ),
    InvoiceData(
      id: 'INV-0037',
      client: 'DataStream AI',
      amount: '\$2,450.00',
      date: 'Feb 22, 2026',
      status: 'Paid',
      statusColor: Color(0xFF00D4AA),
    ),
    InvoiceData(
      id: 'INV-0036',
      client: 'CloudSync GmbH',
      amount: '\$670.00',
      date: 'Feb 20, 2026',
      status: 'Draft',
      statusColor: Color(0xFF8B949E),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          color: const Color(0xFF0D1117),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  _filters.asMap().entries.map((e) {
                    final selected = e.key == _filterIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _filterIndex = e.key),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color:
                              selected
                                  ? const Color(0xFF00D4AA)
                                  : const Color(0xFF161B22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                selected
                                    ? const Color(0xFF00D4AA)
                                    : const Color(0xFF21262D),
                          ),
                        ),
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                selected
                                    ? Colors.black
                                    : const Color(0xFF8B949E),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ),
        // Summary row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${_invoices.length} invoices',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4AA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF00D4AA).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.add, color: Color(0xFF00D4AA), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'New Invoice',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00D4AA),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: _invoices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => InvoiceCard(data: _invoices[i]),
          ),
        ),
      ],
    );
  }
}

class InvoiceData {
  final String id, client, amount, date, status;
  final Color statusColor;
  const InvoiceData({
    required this.id,
    required this.client,
    required this.amount,
    required this.date,
    required this.status,
    required this.statusColor,
  });
}

class InvoiceCard extends StatelessWidget {
  final InvoiceData data;
  const InvoiceCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF00D4AA).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Color(0xFF00D4AA),
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
                        color: Color(0xFF8B949E),
                      ),
                    ),
                    const Text(
                      ' · ',
                      style: TextStyle(color: Color(0xFF484F58)),
                    ),
                    Text(
                      data.date,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8B949E),
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
                    letterSpacing: 0.4,
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

// ─── Agents Tab ───────────────────────────
