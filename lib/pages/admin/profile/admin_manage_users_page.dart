import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _success = Color(0xFF24A148);
const _warning = Color(0xFFFF832B);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);

class AdminManageUsersPage extends StatefulWidget {
  const AdminManageUsersPage({super.key});

  @override
  State<AdminManageUsersPage> createState() => _AdminManageUsersPageState();
}

class _AdminManageUsersPageState extends State<AdminManageUsersPage>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  final TextEditingController _searchController = TextEditingController();

  String _selectedRole = 'All';
  final List<String> _roleFilters = ['All', 'Admin', 'Agent', 'User'];

  final List<Map<String, dynamic>> _allUsers = [
    {
      "name": "John Admin",
      "email": "admin@example.com",
      "role": "admin",
      "status": "active",
    },
    {
      "name": "Sarah Agent",
      "email": "agent@example.com",
      "role": "agent",
      "status": "active",
    },
    {
      "name": "Mike User",
      "email": "user@example.com",
      "role": "user",
      "status": "inactive",
    },
    {
      "name": "Anna Cruz",
      "email": "anna@example.com",
      "role": "user",
      "status": "active",
    },
    {
      "name": "Leo Santos",
      "email": "leo@example.com",
      "role": "agent",
      "status": "active",
    },
    {
      "name": "Diana Reyes",
      "email": "diana@example.com",
      "role": "admin",
      "status": "active",
    },
  ];

  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _users = List.from(_allUsers);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _animController.forward(),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _users =
          _allUsers.where((u) {
            final matchSearch =
                (u['name'] ?? '').toLowerCase().contains(q) ||
                (u['email'] ?? '').toLowerCase().contains(q);
            final matchRole =
                _selectedRole == 'All' ||
                (u['role'] ?? '').toLowerCase() == _selectedRole.toLowerCase();
            return matchSearch && matchRole;
          }).toList();
    });
    _animController.forward(from: 0);
  }

  int _count(String role) =>
      _allUsers
          .where((u) => (u['role'] ?? '').toLowerCase() == role.toLowerCase())
          .length;

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return _primary;
      case 'agent':
        return _warning;
      default:
        return _success;
    }
  }

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'agent':
        return Icons.support_agent_outlined;
      default:
        return Icons.person_outline;
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String selectedRole = 'user';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => StatefulBuilder(
            builder:
                (ctx, setModalState) => Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    top: 24,
                    left: 24,
                    right: 24,
                  ),
                  decoration: const BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_primary, _primaryDark],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person_add_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Add New User',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _sheetField(nameCtrl, 'Full Name', Icons.person_outline),
                      const SizedBox(height: 12),
                      _sheetField(
                        emailCtrl,
                        'Email Address',
                        Icons.email_outlined,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Role',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _inkSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children:
                            ['admin', 'agent', 'user'].map((r) {
                              final isSelected = selectedRole == r;
                              final color = _roleColor(r);
                              return Expanded(
                                child: GestureDetector(
                                  onTap:
                                      () =>
                                          setModalState(() => selectedRole = r),
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? color
                                              : color.withOpacity(0.07),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color:
                                            isSelected
                                                ? color
                                                : color.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Text(
                                      r.toUpperCase(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            isSelected ? Colors.white : color,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (nameCtrl.text.trim().isNotEmpty &&
                                emailCtrl.text.trim().isNotEmpty) {
                              setState(() {
                                _allUsers.add({
                                  'name': nameCtrl.text.trim(),
                                  'email': emailCtrl.text.trim(),
                                  'role': selectedRole,
                                  'status': 'active',
                                });
                                _filter();
                              });
                              Navigator.pop(ctx);
                            }
                          },
                          child: const Text(
                            'Add User',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _sheetField(TextEditingController c, String hint, IconData icon) =>
      Container(
        decoration: BoxDecoration(
          color: _surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: TextField(
          controller: c,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _inkTertiary, fontSize: 14),
            prefixIcon: Icon(icon, size: 18, color: _primary),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _surfaceSubtle,
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddUserDialog,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.person_add_outlined),
        ),
        body: Column(
          children: [
            // ── Gradient AppBar ──────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEB1E23), Color(0xFF760F12)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Manage Users',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Create, update, and deactivate users',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Scrollable body ──────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _filter(),
                color: _primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Stat Pills
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Row(
                          children: [
                            _StatPill(
                              icon: Icons.admin_panel_settings_outlined,
                              label: 'Admins',
                              value: '${_count('admin')}',
                              color: _primary,
                            ),
                            const SizedBox(width: 10),
                            _StatPill(
                              icon: Icons.support_agent_outlined,
                              label: 'Agents',
                              value: '${_count('agent')}',
                              color: _warning,
                            ),
                            const SizedBox(width: 10),
                            _StatPill(
                              icon: Icons.person_outline,
                              label: 'Users',
                              value: '${_count('user')}',
                              color: _success,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Search
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => _filter(),
                            decoration: const InputDecoration(
                              hintText: 'Search by name or email...',
                              hintStyle: TextStyle(
                                color: _inkTertiary,
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: _inkTertiary,
                                size: 20,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Role filter chips
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children:
                                _roleFilters.map((r) {
                                  final isSelected = _selectedRole == r;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() => _selectedRole = r);
                                      _filter();
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected ? _primary : _surface,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color:
                                              isSelected ? _primary : _border,
                                        ),
                                        boxShadow:
                                            isSelected
                                                ? [
                                                  BoxShadow(
                                                    color: _primary.withOpacity(
                                                      0.25,
                                                    ),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ]
                                                : [],
                                      ),
                                      child: Text(
                                        r,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              isSelected
                                                  ? Colors.white
                                                  : _inkSecondary,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                      ),
                    ),

                    // Section header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
                              onTap: _filter,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _border),
                                ),
                                child: const Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                  color: _inkSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // List
                    if (_users.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: _primary.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person_search_outlined,
                                  color: _primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No users found',
                                style: TextStyle(
                                  color: _inkSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Try adjusting your search or filter',
                                style: TextStyle(
                                  color: _inkTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final u = _users[index];
                            final delay = index * 0.07;
                            return AnimatedBuilder(
                              animation: _animController,
                              builder: (context, child) {
                                final t = (_animController.value - delay).clamp(
                                  0.0,
                                  1.0,
                                );
                                return Opacity(
                                  opacity: t,
                                  child: Transform.translate(
                                    offset: Offset(0, 18 * (1 - t)),
                                    child: child,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _UserCard(
                                  user: u,
                                  initials: _initials(u['name'] ?? ''),
                                  roleColor: _roleColor(u['role'] ?? ''),
                                  roleIcon: _roleIcon(u['role'] ?? ''),
                                  onDelete: () {
                                    setState(() {
                                      _allUsers.removeWhere(
                                        (x) => x['email'] == u['email'],
                                      );
                                      _filter();
                                    });
                                  },
                                ),
                              ),
                            );
                          }, childCount: _users.length),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── User Card ─────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String initials;
  final Color roleColor;
  final IconData roleIcon;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.initials,
    required this.roleColor,
    required this.roleIcon,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = user['name'] ?? 'Unknown';
    final email = user['email'] ?? '—';
    final role = (user['role'] ?? 'user').toString();
    final isActive = (user['status'] ?? 'active') == 'active';

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Gradient avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [roleColor, roleColor.withOpacity(0.65)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isActive ? _success : _inkTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: const TextStyle(fontSize: 12, color: _inkSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: roleColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(roleIcon, size: 10, color: roleColor),
                            const SizedBox(width: 4),
                            Text(
                              role.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: roleColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (isActive ? _success : _inkTertiary)
                              .withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isActive ? 'ACTIVE' : 'INACTIVE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: isActive ? _success : _inkTertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Action buttons
            Column(
              children: [
                _iconBtn(Icons.edit_outlined, _inkSecondary, () {}),
                const SizedBox(height: 6),
                _iconBtn(Icons.delete_outline, _primary, onDelete),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      );
}

// ── Stat Pill ─────────────────────────────────────────────────────────────────

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
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: _inkSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
