import 'package:flutter/material.dart';
import 'dart:math' as math;

// ─── End Users (index 3) ──────────────────────────────────────────────────────

class EndUsersPage extends StatelessWidget {
  const EndUsersPage({super.key});

  static const _users = [
    UserItem(
      name: 'Lena Hartmann',
      company: 'Acme Corp',
      plan: 'Enterprise',
      tickets: 3,
      initials: 'LH',
      color: Color(0xFF6366F1),
    ),
    UserItem(
      name: 'Carlos Mendes',
      company: 'BlueSky Ltd.',
      plan: 'Pro',
      tickets: 1,
      initials: 'CM',
      color: Color(0xFF10B981),
    ),
    UserItem(
      name: 'Aisha Patel',
      company: 'NovaTech Inc.',
      plan: 'Enterprise',
      tickets: 2,
      initials: 'AP',
      color: Color(0xFFF59E0B),
    ),
    UserItem(
      name: 'Tom Nguyen',
      company: 'PixelWave Co.',
      plan: 'Starter',
      tickets: 0,
      initials: 'TN',
      color: Color(0xFF64748B),
    ),
    UserItem(
      name: 'Sofia Rossi',
      company: 'DataStream AI',
      plan: 'Pro',
      tickets: 1,
      initials: 'SR',
      color: Color(0xFF0EA5E9),
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
                'End Users',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF162032),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E3050)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.search, color: Color(0xFF64748B), size: 18),
                    SizedBox(width: 10),
                    Text(
                      'Search users...',
                      style: TextStyle(color: Color(0xFF4A5568), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF162032),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1E3050)),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF64748B),
                      size: 13,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'You can view end users and create tickets on their behalf.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            itemCount: _users.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => UserCard(data: _users[i]),
          ),
        ),
      ],
    );
  }
}

class UserItem {
  final String name, company, plan, initials;
  final int tickets;
  final Color color;
  const UserItem({
    required this.name,
    required this.company,
    required this.plan,
    required this.tickets,
    required this.initials,
    required this.color,
  });
}

class UserCard extends StatelessWidget {
  final UserItem data;
  const UserCard({super.key, required this.data});

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
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: data.color.withOpacity(0.12),
              border: Border.all(color: data.color.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(
                data.initials,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: data.color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.company,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 5),
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
                    if (data.tickets > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${data.tickets} open ticket${data.tickets > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                ),
              ),
              child: const Text(
                '+ Ticket',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6366F1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
