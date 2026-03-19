import 'package:flutter/material.dart';
import 'dart:math' as math;

// ─── Subscriptions (Quick Action) ────────────────────────────────────────────

class SubscriptionsPage extends StatelessWidget {
  const SubscriptionsPage({super.key});

  static const _subs = [
    SubItem(
      company: 'Acme Corp',
      plan: 'Enterprise',
      seats: 50,
      status: 'Expiring',
      renewDate: 'Mar 06, 2026',
      mrr: '\$2,400',
      statusColor: Color(0xFFF43F5E),
    ),
    SubItem(
      company: 'NovaTech Inc.',
      plan: 'Enterprise',
      seats: 30,
      status: 'Active',
      renewDate: 'Apr 15, 2026',
      mrr: '\$1,800',
      statusColor: Color(0xFF10B981),
    ),
    SubItem(
      company: 'BlueSky Ltd.',
      plan: 'Pro',
      seats: 10,
      status: 'Active',
      renewDate: 'Apr 28, 2026',
      mrr: '\$490',
      statusColor: Color(0xFF10B981),
    ),
    SubItem(
      company: 'PixelWave Co.',
      plan: 'Pro',
      seats: 8,
      status: 'Expiring',
      renewDate: 'Mar 09, 2026',
      mrr: '\$392',
      statusColor: Color(0xFFF59E0B),
    ),
    SubItem(
      company: 'DataStream AI',
      plan: 'Enterprise',
      seats: 20,
      status: 'Active',
      renewDate: 'May 01, 2026',
      mrr: '\$960',
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
                'Subscriptions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1060), Color(0xFF0C1424)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Active Subscriptions',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '5 Total',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF43F5E).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '2 Expiring',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF43F5E),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '3 Active',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            itemCount: _subs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => SubCard(data: _subs[i]),
          ),
        ),
      ],
    );
  }
}

class SubItem {
  final String company, plan, status, renewDate, mrr;
  final int seats;
  final Color statusColor;
  const SubItem({
    required this.company,
    required this.plan,
    required this.seats,
    required this.status,
    required this.renewDate,
    required this.mrr,
    required this.statusColor,
  });
}

class SubCard extends StatelessWidget {
  final SubItem data;
  const SubCard({super.key, required this.data});

  Color get _planColor =>
      data.plan == 'Enterprise'
          ? const Color(0xFF6366F1)
          : data.plan == 'Pro'
          ? const Color(0xFF0EA5E9)
          : const Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF162032),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3050)),
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
                  color: _planColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.subscriptions_outlined,
                  color: _planColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.company,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _planColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            data.plan,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _planColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${data.seats} seats',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
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
                  const SizedBox(height: 4),
                  Text(
                    data.mrr,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: const Color(0xFF1E3050)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 12,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 5),
              Text(
                'Renews: ${data.renewDate}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.25),
                  ),
                ),
                child: const Text(
                  'View',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6366F1),
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
