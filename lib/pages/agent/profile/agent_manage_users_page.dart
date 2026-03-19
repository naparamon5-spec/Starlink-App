import 'package:flutter/material.dart';

class AgentManageUsersPage extends StatefulWidget {
  const AgentManageUsersPage({super.key});

  @override
  State<AgentManageUsersPage> createState() => _AgentManageUsersPageState();
}

class _AgentManageUsersPageState extends State<AgentManageUsersPage> {
  int _filterIndex = 0;
  final _filters = ['All', 'Active', 'Inactive'];
  String _search = '';

  static const _users = [
    _UserItem(
      name: 'Lena Hartmann',
      email: 'l.hartmann@acme.com',
      company: 'Acme Corp',
      plan: 'Enterprise',
      status: 'Active',
      initials: 'LH',
      openTickets: 3,
      joinDate: 'Jan 12, 2024',
      color: Color(0xFF6366F1),
    ),
    _UserItem(
      name: 'Carlos Mendes',
      email: 'c.mendes@bluesky.io',
      company: 'BlueSky Ltd.',
      plan: 'Pro',
      status: 'Active',
      initials: 'CM',
      openTickets: 1,
      joinDate: 'Mar 05, 2024',
      color: Color(0xFF10B981),
    ),
    _UserItem(
      name: 'Aisha Patel',
      email: 'a.patel@novatech.com',
      company: 'NovaTech Inc.',
      plan: 'Enterprise',
      status: 'Active',
      initials: 'AP',
      openTickets: 2,
      joinDate: 'Feb 18, 2024',
      color: Color(0xFFF59E0B),
    ),
    _UserItem(
      name: 'Tom Nguyen',
      email: 't.nguyen@pixelwave.co',
      company: 'PixelWave Co.',
      plan: 'Starter',
      status: 'Inactive',
      initials: 'TN',
      openTickets: 0,
      joinDate: 'Dec 01, 2023',
      color: Color(0xFF64748B),
    ),
    _UserItem(
      name: 'Sofia Rossi',
      email: 's.rossi@datastream.ai',
      company: 'DataStream AI',
      plan: 'Pro',
      status: 'Active',
      initials: 'SR',
      openTickets: 1,
      joinDate: 'Apr 22, 2024',
      color: Color(0xFF0EA5E9),
    ),
    _UserItem(
      name: 'Hans Müller',
      email: 'h.muller@cloudsync.de',
      company: 'CloudSync GmbH',
      plan: 'Enterprise',
      status: 'Inactive',
      initials: 'HM',
      openTickets: 0,
      joinDate: 'Nov 14, 2023',
      color: Color(0xFF8B5CF6),
    ),
  ];

  List<_UserItem> get _filtered {
    var list =
        _users.where((u) {
          final matchFilter =
              _filterIndex == 0 || u.status == _filters[_filterIndex];
          final matchSearch =
              _search.isEmpty ||
              u.name.toLowerCase().contains(_search.toLowerCase()) ||
              u.company.toLowerCase().contains(_search.toLowerCase()) ||
              u.email.toLowerCase().contains(_search.toLowerCase());
          return matchFilter && matchSearch;
        }).toList();
    return list;
  }

  int get _activeCount => _users.where((u) => u.status == 'Active').length;
  int get _inactiveCount => _users.where((u) => u.status == 'Inactive').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1923),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1923),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF162032),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E3050)),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        title: const Text(
          'Manage Users',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Header summary + search ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            color: const Color(0xFF0F1923),
            child: Column(
              children: [
                // Stats strip
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162032),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1E3050)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Strip(
                        value: '${_users.length}',
                        label: 'Total',
                        color: const Color(0xFF6366F1),
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: const Color(0xFF1E3050),
                      ),
                      _Strip(
                        value: '$_activeCount',
                        label: 'Active',
                        color: const Color(0xFF22C55E),
                      ),
                      Container(
                        width: 1,
                        height: 28,
                        color: const Color(0xFF1E3050),
                      ),
                      _Strip(
                        value: '$_inactiveCount',
                        label: 'Inactive',
                        color: const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Search bar
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
                    children: [
                      const Icon(
                        Icons.search,
                        color: Color(0xFF64748B),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _search = v),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search by name, company or email...',
                            hintStyle: TextStyle(
                              color: Color(0xFF4A5568),
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Filter chips
                Row(
                  children:
                      _filters.asMap().entries.map((e) {
                        final sel = e.key == _filterIndex;
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
                                  sel
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFF162032),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    sel
                                        ? const Color(0xFF6366F1)
                                        : const Color(0xFF1E3050),
                              ),
                            ),
                            child: Text(
                              e.value,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    sel
                                        ? Colors.white
                                        : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),

                // Permission note
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
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
                        'View only · You can create tickets on behalf of users.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── User list ─────────────────────────────────────────────────────
          Expanded(
            child:
                _filtered.isEmpty
                    ? Center(
                      child: Text(
                        'No users found',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 14,
                        ),
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _UserCard(data: _filtered[i]),
                    ),
          ),
        ],
      ),
    );
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

class _UserItem {
  final String name, email, company, plan, status, initials, joinDate;
  final int openTickets;
  final Color color;
  const _UserItem({
    required this.name,
    required this.email,
    required this.company,
    required this.plan,
    required this.status,
    required this.initials,
    required this.openTickets,
    required this.joinDate,
    required this.color,
  });
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _Strip extends StatelessWidget {
  final String value, label;
  final Color color;
  const _Strip({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Column(
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

class _UserCard extends StatelessWidget {
  final _UserItem data;
  const _UserCard({required this.data});

  Color get _planColor {
    switch (data.plan) {
      case 'Enterprise':
        return const Color(0xFF6366F1);
      case 'Pro':
        return const Color(0xFF0EA5E9);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color get _statusColor =>
      data.status == 'Active'
          ? const Color(0xFF22C55E)
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
          // Row 1: avatar + name + ticket button
          Row(
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
                      data.email,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              // Create ticket button (agent privilege)
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
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

          const SizedBox(height: 10),
          Container(height: 1, color: const Color(0xFF1E3050)),
          const SizedBox(height: 10),

          // Row 2: badges + join date
          Row(
            children: [
              // Plan badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _planColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
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
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.status,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                  ),
                ),
              ),
              if (data.openTickets > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${data.openTickets} open ticket${data.openTickets > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              const Icon(
                Icons.calendar_today_outlined,
                size: 11,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Text(
                data.joinDate,
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
