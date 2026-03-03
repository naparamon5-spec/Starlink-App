import 'package:flutter/material.dart';
// ─── Agents Tab (index 1) ─────────────────────────────────────────────────────

class AgentTeamPage extends StatelessWidget {
  const AgentTeamPage();

  static const _agents = [
    AgentData(
      name: 'James Davis',
      role: 'Support Agent · L2',
      initials: 'JD',
      status: 'Online',
      statusColor: Color(0xFF22C55E),
      tickets: 12,
      resolved: 7,
      gradA: Color(0xFF6366F1),
      gradB: Color(0xFF8B5CF6),
    ),
    AgentData(
      name: 'Maria Santos',
      role: 'Support Agent · L1',
      initials: 'MS',
      status: 'Online',
      statusColor: Color(0xFF22C55E),
      tickets: 9,
      resolved: 6,
      gradA: Color(0xFF10B981),
      gradB: Color(0xFF0EA5E9),
    ),
    AgentData(
      name: 'Kevin Lee',
      role: 'Senior Agent · L3',
      initials: 'KL',
      status: 'Busy',
      statusColor: Color(0xFFF59E0B),
      tickets: 15,
      resolved: 12,
      gradA: Color(0xFFF59E0B),
      gradB: Color(0xFFF43F5E),
    ),
    AgentData(
      name: 'Priya Nair',
      role: 'Support Agent · L2',
      initials: 'PN',
      status: 'Away',
      statusColor: Color(0xFF64748B),
      tickets: 6,
      resolved: 5,
      gradA: Color(0xFF0EA5E9),
      gradB: Color(0xFF6366F1),
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
                'Agent Team',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF162032),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E3050)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    TStat(
                      value: '${_agents.length}',
                      label: 'Total',
                      color: const Color(0xFF6366F1),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: const Color(0xFF1E3050),
                    ),
                    TStat(
                      value: '2',
                      label: 'Online',
                      color: const Color(0xFF22C55E),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: const Color(0xFF1E3050),
                    ),
                    TStat(
                      value: '1',
                      label: 'Busy',
                      color: const Color(0xFFF59E0B),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: const Color(0xFF1E3050),
                    ),
                    TStat(
                      value: '1',
                      label: 'Away',
                      color: const Color(0xFF64748B),
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
            itemCount: _agents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => AgentTeamCard(data: _agents[i]),
          ),
        ),
      ],
    );
  }
}

class AgentData {
  final String name, role, initials, status;
  final Color statusColor, gradA, gradB;
  final int tickets, resolved;
  const AgentData({
    required this.name,
    required this.role,
    required this.initials,
    required this.status,
    required this.statusColor,
    required this.tickets,
    required this.resolved,
    required this.gradA,
    required this.gradB,
  });
}

class TStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const TStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }
}

class AgentTeamCard extends StatelessWidget {
  final AgentData data;
  const AgentTeamCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final pct = data.tickets > 0 ? data.resolved / data.tickets : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF162032),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3050)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [data.gradA, data.gradB],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    data.initials,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 1,
                bottom: 1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: data.statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF162032),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      data.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
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
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  data.role,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          children: [
                            Container(
                              height: 4,
                              color: const Color(0xFF6366F1).withOpacity(0.15),
                            ),
                            FractionallySizedBox(
                              widthFactor: pct,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [data.gradA, data.gradB],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${data.resolved}/${data.tickets}',
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
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Color(0xFF64748B), size: 20),
        ],
      ),
    );
  }
}
