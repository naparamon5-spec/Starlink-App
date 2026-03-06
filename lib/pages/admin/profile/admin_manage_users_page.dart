import 'package:flutter/material.dart';

class AdminManageUsersPage extends StatefulWidget {
  const AdminManageUsersPage({super.key});

  @override
  State<AdminManageUsersPage> createState() => _AdminManageUsersPageState();
}

class _AdminManageUsersPageState extends State<AdminManageUsersPage>
    with TickerProviderStateMixin {
  late AnimationController _animController;

  final TextEditingController _searchController = TextEditingController();

  /// Local Users List (Temporary)
  final List<Map<String, dynamic>> _allUsers = [
    {"name": "John Admin", "email": "admin@example.com", "role": "admin"},
    {"name": "Sarah Agent", "email": "agent@example.com", "role": "agent"},
    {"name": "Mike User", "email": "user@example.com", "role": "user"},
    {"name": "Anna User", "email": "anna@example.com", "role": "user"},
  ];

  List<Map<String, dynamic>> _users = [];

  /// ── Design Tokens ───────────────────────────────
  static const _primary = Color(0xFF0F62FE);
  static const _success = Color(0xFF24A148);
  static const _danger = Color(0xFFDA1E28);
  static const _warning = Color(0xFFFF832B);

  static const _ink = Color(0xFF161616);
  static const _inkSecondary = Color(0xFF6F6F6F);
  static const _inkTertiary = Color(0xFFA8A8A8);

  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _users = List.from(_allUsers);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// LOCAL SEARCH FILTER
  void _filterUsers() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _users =
          _allUsers.where((u) {
            final name = (u['name'] ?? '').toLowerCase();
            final email = (u['email'] ?? '').toLowerCase();

            return name.contains(query) || email.contains(query);
          }).toList();
    });

    _animController.forward(from: 0);
  }

  /// COUNTS
  int get _adminCount =>
      _users.where((u) => (u['role'] ?? '').toLowerCase() == 'admin').length;

  int get _agentCount =>
      _users.where((u) => (u['role'] ?? '').toLowerCase() == 'agent').length;

  int get _userCount =>
      _users.where((u) => (u['role'] ?? '').toLowerCase() == 'user').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: RefreshIndicator(
        onRefresh: () async {
          _filterUsers();
        },
        color: _primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildStatChips()),

            /// SEARCH
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: _surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _filterUsers(),
                    decoration: const InputDecoration(
                      hintText: 'Search users...',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search, color: _inkTertiary),
                    ),
                  ),
                ),
              ),
            ),

            /// SECTION HEADER
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  children: [
                    const Text(
                      'User Records',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_users.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _filterUsers,
                      child: const Icon(
                        Icons.refresh_rounded,
                        size: 18,
                        color: _inkTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// LIST
            if (_users.isEmpty)
              SliverFillRemaining(child: _buildEmpty())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        final delay = index * 0.07;

                        final t = (_animController.value - delay).clamp(
                          0.0,
                          1.0,
                        );

                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1 - t)),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildUserCard(_users[index]),
                      ),
                    );
                  }, childCount: _users.length),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// STATS
  Widget _buildStatChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          _StatPill(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Admins',
            value: '$_adminCount',
            color: _primary,
          ),
          const SizedBox(width: 10),
          _StatPill(
            icon: Icons.support_agent_outlined,
            label: 'Agents',
            value: '$_agentCount',
            color: _warning,
          ),
          const SizedBox(width: 10),
          _StatPill(
            icon: Icons.person_outline,
            label: 'Users',
            value: '$_userCount',
            color: _success,
          ),
        ],
      ),
    );
  }

  /// CARD
  Widget _buildUserCard(Map<String, dynamic> u) {
    final name = u['name'] ?? 'Unknown';
    final email = u['email'] ?? '—';
    final role = (u['role'] ?? 'user').toString();

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _primary.withOpacity(0.1),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(email),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            role.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Text('No users found', style: TextStyle(color: _inkSecondary)),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF6F6F6F)),
            ),
          ],
        ),
      ),
    );
  }
}
