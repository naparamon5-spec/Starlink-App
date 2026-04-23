import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_service.dart';
import 'view-user/admin_view_user_details_page.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _success = Color(0xFF24A148);
const _warning = Color(0xFFFF832B);
const _info = Color(0xFF0043CE);
const _purple = Color(0xFF8A3FFC);
const _teal = Color(0xFF009D9A);
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

class _AdminManageUsersPageState extends State<AdminManageUsersPage> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedRole = 'All';

  final List<String> _roleFilters = [
    'All',
    'Admin',
    'Agent',
    'Customer',
    'End User',
    'Biller',
  ];

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _currentUserRole = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUserRole();
    _fetchUsers();
  }

  Future<void> _loadCurrentUserRole() async {
    try {
      final me = await ApiService.getMe();
      if (!mounted) return;
      if (me['status'] == 'success') {
        final data = me['data'];
        final role =
            (data is Map ? (data['role'] ?? data['user_role'] ?? '') : '')
                .toString()
                .toLowerCase()
                .trim();
        if (mounted) setState(() => _currentUserRole = role);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.getUsersList();

      if (result['status'] == 'success') {
        final raw = result['data'];
        List<dynamic> list = [];

        if (raw is List) {
          list = raw;
        } else if (raw is Map && raw['data'] is List) {
          list = raw['data'] as List;
        }

        setState(() {
          _allUsers =
              list
                  .whereType<Map>()
                  .map((u) => Map<String, dynamic>.from(u))
                  .toList();
          _isLoading = false;
        });
        _filter();
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load users.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ── Filter / search ────────────────────────────────────────────────────────
  void _filter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _users =
          _allUsers.where((u) {
            final matchSearch =
                (u['name'] ?? '').toLowerCase().contains(q) ||
                (u['first_name'] ?? '').toLowerCase().contains(q) ||
                (u['last_name'] ?? '').toLowerCase().contains(q) ||
                (u['email'] ?? '').toLowerCase().contains(q) ||
                (u['position'] ?? '').toLowerCase().contains(q);

            final role = _normaliseRole(u['role'] ?? '');
            final matchRole =
                _selectedRole == 'All' ||
                role.toLowerCase() == _selectedRole.toLowerCase();

            return matchSearch && matchRole;
          }).toList();
    });
  }

  String _normaliseRole(String raw) {
    switch (raw.toLowerCase()) {
      case 'end_user':
        return 'End User';
      case 'admin':
        return 'Admin';
      case 'agent':
        return 'Agent';
      case 'customer':
        return 'Customer';
      case 'biller':
        return 'Biller';
      default:
        return raw;
    }
  }

  int _count(String roleLabel) =>
      _allUsers.where((u) {
        final r = _normaliseRole(u['role'] ?? '');
        final inactive = (u['inactive'] ?? 'N').toString().toUpperCase();
        return r.toLowerCase() == roleLabel.toLowerCase() && inactive != 'Y';
      }).length;

  Color _roleColor(String rawRole) {
    switch (rawRole.toLowerCase()) {
      case 'admin':
        return _primary;
      case 'agent':
        return _warning;
      case 'customer':
        return _info;
      case 'end_user':
        return _success;
      case 'biller':
        return _purple;
      default:
        return _teal;
    }
  }

  IconData _roleIcon(String rawRole) {
    switch (rawRole.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'agent':
        return Icons.support_agent_outlined;
      case 'customer':
        return Icons.business_outlined;
      case 'end_user':
        return Icons.person_outline;
      case 'biller':
        return Icons.receipt_long_outlined;
      default:
        return Icons.badge_outlined;
    }
  }

  String _displayName(Map<String, dynamic> u) {
    final first = u['first_name']?.toString().trim() ?? '';
    final last = u['last_name']?.toString().trim() ?? '';
    final name = u['name']?.toString().trim() ?? '';
    if (first.isNotEmpty || last.isNotEmpty) return '$first $last'.trim();
    return name.isNotEmpty ? name : 'Unknown';
  }

  String _initials(Map<String, dynamic> u) {
    final name = _displayName(u);
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  // ── Navigate to detail ─────────────────────────────────────────────────────
  void _openUserDetail(Map<String, dynamic> user) {
    final id = user['id']?.toString() ?? '';
    if (id.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminUserDetailPage(userId: id)),
    ).then((_) => _fetchUsers());
  }

  // ── Add-user bottom sheet ──────────────────────────────────────────────────
  void _showAddUserDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder:
          (_) => CreateUserSheet(
            currentUserRole: _currentUserRole,
            onCreated: () {
              _fetchUsers();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'User created successfully.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: _success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            onError: (msg) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    msg,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: _primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
          ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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
            // ── Gradient AppBar ────────────────────────────────────────────
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Manage Users',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              _isLoading
                                  ? 'Loading...'
                                  : '${_allUsers.length} users total',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // IconButton(
                      //   onPressed: _fetchUsers,
                      //   icon: const Icon(
                      //     Icons.refresh_rounded,
                      //     color: Colors.white70,
                      //     size: 20,
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(color: _primary),
                      )
                      : _errorMessage != null
                      ? _buildError()
                      : RefreshIndicator(
                        onRefresh: _fetchUsers,
                        color: _primary,
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            // Stat Pills
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  20,
                                  20,
                                  0,
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      _StatPill(
                                        icon:
                                            Icons.admin_panel_settings_outlined,
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
                                        icon: Icons.business_outlined,
                                        label: 'Customers',
                                        value: '${_count('customer')}',
                                        color: _info,
                                      ),
                                      const SizedBox(width: 10),
                                      _StatPill(
                                        icon: Icons.person_outline,
                                        label: 'End Users',
                                        value: '${_count('end_user')}',
                                        color: _success,
                                      ),
                                      const SizedBox(width: 10),
                                      _StatPill(
                                        icon: Icons.receipt_long_outlined,
                                        label: 'Billers',
                                        value: '${_count('biller')}',
                                        color: _purple,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Search
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  16,
                                  20,
                                  0,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _border),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (_) => _filter(),
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Search by name, email or position...',
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
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  12,
                                  20,
                                  0,
                                ),
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
                                              margin: const EdgeInsets.only(
                                                right: 8,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    isSelected
                                                        ? _primary
                                                        : _surface,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color:
                                                      isSelected
                                                          ? _primary
                                                          : _border,
                                                ),
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
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  20,
                                  20,
                                  12,
                                ),
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
                                  ],
                                ),
                              ),
                            ),

                            // User list
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
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  100,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final u = _users[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: RepaintBoundary(
                                        child: _UserCard(
                                          user: u,
                                          initials: _initials(u),
                                          roleColor: _roleColor(
                                            u['role'] ?? '',
                                          ),
                                          roleIcon: _roleIcon(u['role'] ?? ''),
                                          normalisedRole: _normaliseRole(
                                            u['role'] ?? '',
                                          ),
                                          onDelete: () {
                                            setState(() {
                                              _allUsers.removeWhere(
                                                (x) =>
                                                    x['id'] == u['id'] ||
                                                    x['email'] == u['email'],
                                              );
                                              _filter();
                                            });
                                          },
                                          onViewDetail:
                                              () => _openUserDetail(u),
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

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              color: _primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Could not load users',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: _inkSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchUsers,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── User Card ──────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String initials;
  final Color roleColor;
  final IconData roleIcon;
  final String normalisedRole;
  final VoidCallback onDelete;
  final VoidCallback onViewDetail;

  const _UserCard({
    required this.user,
    required this.initials,
    required this.roleColor,
    required this.roleIcon,
    required this.normalisedRole,
    required this.onDelete,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    final first = user['first_name']?.toString().trim() ?? '';
    final last = user['last_name']?.toString().trim() ?? '';
    final fallback = user['name']?.toString().trim() ?? 'Unknown';
    final name =
        (first.isNotEmpty || last.isNotEmpty)
            ? '$first $last'.trim()
            : fallback;
    final email = (user['email'] ?? '—').toString();
    final position = (user['position'] ?? '').toString().trim();
    final isActive = (user['inactive'] ?? 'N').toString().toUpperCase() != 'Y';

    return GestureDetector(
      onTap: onViewDetail,
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
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
                          // decoration: BoxDecoration(
                          //   color: isActive ? _success : _inkTertiary,
                          //   shape: BoxShape.circle,
                          // ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _inkSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (position.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        position,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _inkTertiary,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
                            border: Border.all(
                              color: roleColor.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(roleIcon, size: 10, color: roleColor),
                              const SizedBox(width: 4),
                              Text(
                                normalisedRole.toUpperCase(),
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
                  _iconBtn(
                    Icons.chevron_right_rounded,
                    _inkSecondary,
                    onViewDetail,
                  ),
                  const SizedBox(height: 6),
                  _iconBtn(
                    Icons.delete_outline,
                    _primary,
                    () => _confirmDelete(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final first = user['first_name']?.toString().trim() ?? '';
    final last = user['last_name']?.toString().trim() ?? '';
    final name =
        (first.isNotEmpty || last.isNotEmpty)
            ? '$first $last'.trim()
            : (user['name']?.toString().trim() ?? 'this user');

    showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: _primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Remove User',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ],
            ),
            content: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: _inkSecondary,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'Are you sure you want to remove '),
                  TextSpan(
                    text: name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const TextSpan(
                    text: ' from the list? This action cannot be undone.',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: TextButton.styleFrom(
                  foregroundColor: _inkSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx, true);
                  onDelete();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                ),
                child: const Text(
                  'Remove',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
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

// ── Stat Pill ──────────────────────────────────────────────────────────────────

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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    constraints: const BoxConstraints(minWidth: 90),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.2)),
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
  );
}

// ── Create User Bottom Sheet ───────────────────────────────────────────────────

class CreateUserSheet extends StatefulWidget {
  final VoidCallback onCreated;
  final void Function(String msg) onError;
  final String currentUserRole;

  const CreateUserSheet({
    super.key,
    required this.onCreated,
    required this.onError,
    required this.currentUserRole,
  });

  @override
  State<CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<CreateUserSheet> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _companyEmailCtrl = TextEditingController();

  List<Map<String, dynamic>> _roles = [];
  bool _loadingRoles = true;
  String? _selectedRoleValue;
  String? _selectedRoleLabel;

  List<Map<String, dynamic>> _companies = [];
  bool _loadingCompanies = false;
  String? _selectedCompanyValue;
  String? _selectedCompanyLabel;

  String? _roleError;
  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;

  bool _isSaving = false;

  bool get _companyEnabled => _selectedRoleValue != null;

  bool get _isEndUserRole =>
      _selectedRoleValue?.toLowerCase() == 'end_user' ||
      _selectedRoleLabel?.toLowerCase() == 'end user';

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _positionCtrl.dispose();
    _emailCtrl.dispose();
    _companyEmailCtrl.dispose();
    super.dispose();
  }

  List<String> get _allowedRoleValues {
    final role = widget.currentUserRole.toLowerCase().trim();
    if (role == 'agent') return ['customer', 'end_user'];
    return [];
  }

  Future<void> _loadRoles() async {
    setState(() => _loadingRoles = true);
    try {
      final result = await ApiService.getUserRolesList();
      if (result['status'] == 'success') {
        final raw = result['data'];
        final list = raw is List ? raw : [];
        var roles =
            list
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();

        final allowed = _allowedRoleValues;
        if (allowed.isNotEmpty) {
          roles =
              roles.where((r) {
                final val =
                    (r['value'] ?? r['name'] ?? '')
                        .toString()
                        .toLowerCase()
                        .trim();
                final lbl =
                    (r['label'] ?? r['display_name'] ?? '')
                        .toString()
                        .toLowerCase()
                        .trim();
                return allowed.contains(val) ||
                    allowed.contains(lbl) ||
                    allowed.contains(lbl.replaceAll(' ', '_'));
              }).toList();
        }

        setState(() {
          _roles = roles;
          _loadingRoles = false;
        });
      } else {
        setState(() => _loadingRoles = false);
      }
    } catch (_) {
      setState(() => _loadingRoles = false);
    }
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _loadingCompanies = true;
      _companies = [];
      _selectedCompanyValue = null;
      _selectedCompanyLabel = null;
    });

    try {
      if (_isEndUserRole) {
        final result = await ApiService.getEndUserListAll();
        if (!mounted) return;
        final isOk =
            result['status'] == 'success' ||
            result['StatusCode'] == 200 ||
            result['message'] == 'Success';
        if (isOk) {
          final raw = result['data'] as List<dynamic>? ?? [];
          setState(() {
            _companies =
                raw
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .where((e) {
                      final label = (e['label'] as String? ?? '').trim();
                      return label.isNotEmpty && e['value'] != null;
                    })
                    .map(
                      (e) => <String, dynamic>{
                        'label': e['label'].toString().trim(),
                        'value': e['value'].toString(),
                      },
                    )
                    .toList();
          });
        }
      } else {
        final result = await ApiService.getCustomersListAll();
        if (!mounted) return;
        final isOk =
            result['StatusCode'] == 200 ||
            result['message'] == 'Success' ||
            result['status'] == 'success';
        if (isOk) {
          final raw = result['data'] as List<dynamic>? ?? [];
          setState(() {
            _companies =
                raw
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .where((e) {
                      final label = (e['label'] as String? ?? '').trim();
                      final value = e['value']?.toString().trim() ?? '';
                      return label.isNotEmpty && value.isNotEmpty;
                    })
                    .map(
                      (e) => <String, dynamic>{
                        'label': e['label'].toString().trim(),
                        'value': e['value'].toString().trim(),
                      },
                    )
                    .toList();
          });
        }
      }
    } catch (_) {
      // silently ignore
    } finally {
      if (mounted) setState(() => _loadingCompanies = false);
    }
  }

  bool _validate() {
    setState(() {
      _roleError = _selectedRoleValue == null ? 'Please select a role' : null;
      _firstNameError = _firstNameCtrl.text.trim().isEmpty ? 'Required' : null;
      _lastNameError = _lastNameCtrl.text.trim().isEmpty ? 'Required' : null;
      _emailError =
          _emailCtrl.text.trim().isEmpty
              ? 'Required'
              : !_emailCtrl.text.contains('@')
              ? 'Invalid email'
              : null;
    });
    return _roleError == null &&
        _firstNameError == null &&
        _lastNameError == null &&
        _emailError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _isSaving = true);
    try {
      final result = await ApiService.createUser({
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'middle_name': _middleNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'role': _selectedRoleValue,
        'position': _positionCtrl.text.trim(),
        'com_eu_code': _selectedCompanyValue ?? '',
        'company_email': _companyEmailCtrl.text.trim(),
      });
      setState(() => _isSaving = false);
      if (result['status'] == 'success') {
        if (mounted) Navigator.pop(context);
        widget.onCreated();
      } else {
        widget.onError(result['message'] ?? 'Failed to create user.');
      }
    } catch (e) {
      setState(() => _isSaving = false);
      widget.onError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _openRolePicker() {
    if (_loadingRoles) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => _PickerBottomSheet(
            title: 'Select Role',
            items: _roles,
            selectedValue: _selectedRoleValue,
            searchable: false,
            onSelect: (label, value) {
              setState(() {
                _selectedRoleLabel = label;
                _selectedRoleValue = value.toString();
                _roleError = null;
              });
              _loadCompanies();
            },
          ),
    );
  }

  void _openCompanyPicker() {
    if (!_companyEnabled || _loadingCompanies) return;
    final pickerTitle = _isEndUserRole ? 'Select End User' : 'Select Company';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => _PickerBottomSheet(
            title: pickerTitle,
            items: _companies,
            selectedValue: _selectedCompanyValue,
            searchable: true,
            onSelect: (label, value) {
              setState(() {
                _selectedCompanyLabel = label;
                _selectedCompanyValue = value.toString();
              });
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final companyFieldLabel = _isEndUserRole ? 'End User' : 'Company Name';

    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New User',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      Text(
                        'Fill in the details below',
                        style: TextStyle(fontSize: 12, color: _inkTertiary),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: _inkSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: _border),

          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Users Information'),
                  const SizedBox(height: 14),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _fieldLabel(
                          'Role',
                          required: true,
                          error: _roleError,
                          child: _dropdownTile(
                            label: _selectedRoleLabel ?? 'Select Role',
                            isEmpty: _selectedRoleLabel == null,
                            isLoading: _loadingRoles,
                            loadingText: 'Loading...',
                            hasError: _roleError != null,
                            onTap: _openRolePicker,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _fieldLabel(
                          'Position',
                          child: _inputField(controller: _positionCtrl),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _fieldLabel(
                          'First Name',
                          required: true,
                          error: _firstNameError,
                          child: _inputField(
                            controller: _firstNameCtrl,
                            hasError: _firstNameError != null,
                            onChanged:
                                (_) => setState(() => _firstNameError = null),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _fieldLabel(
                          'Last Name',
                          required: true,
                          error: _lastNameError,
                          child: _inputField(
                            controller: _lastNameCtrl,
                            hasError: _lastNameError != null,
                            onChanged:
                                (_) => setState(() => _lastNameError = null),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _fieldLabel(
                          'Middle Name',
                          child: _inputField(controller: _middleNameCtrl),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _fieldLabel(
                    'Email',
                    required: true,
                    error: _emailError,
                    child: _inputField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      hasError: _emailError != null,
                      onChanged: (_) => setState(() => _emailError = null),
                    ),
                  ),
                  const SizedBox(height: 22),

                  Row(
                    children: [
                      _sectionHeader('Company Details'),
                      const SizedBox(width: 8),
                      if (!_companyEnabled)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _inkTertiary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Select role first',
                            style: TextStyle(
                              fontSize: 10,
                              color: _inkTertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _fieldLabel(
                    companyFieldLabel,
                    disabled: !_companyEnabled,
                    child: _dropdownTile(
                      label:
                          _selectedCompanyLabel ??
                          (_isEndUserRole
                              ? 'Select End User'
                              : 'Select Company'),
                      isEmpty: _selectedCompanyLabel == null,
                      isLoading: _loadingCompanies,
                      loadingText:
                          _isEndUserRole
                              ? 'Loading end users...'
                              : 'Loading companies...',
                      disabled: !_companyEnabled,
                      onTap: _openCompanyPicker,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _fieldLabel(
                    'Company Email',
                    disabled: !_companyEnabled,
                    child: _inputField(
                      controller: _companyEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      enabled: _companyEnabled,
                      disabled: !_companyEnabled,
                    ),
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E2B3C),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSaving ? null : _save,
                      icon:
                          _isSaving
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save',
                        style: const TextStyle(
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
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: _ink,
      letterSpacing: -0.2,
    ),
  );

  Widget _fieldLabel(
    String label, {
    required Widget child,
    bool required = false,
    String? error,
    bool disabled = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: disabled ? _inkTertiary : _inkSecondary,
            ),
          ),
          if (required)
            const Text(
              ' *',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _primary,
              ),
            ),
        ],
      ),
      const SizedBox(height: 5),
      child,
      if (error != null) ...[
        const SizedBox(height: 3),
        Text(error, style: const TextStyle(fontSize: 10, color: _primary)),
      ],
    ],
  );

  // ── FIXED: vertically centred input field ──────────────────────────────────
  Widget _inputField({
    required TextEditingController controller,
    bool enabled = true,
    bool disabled = false,
    bool hasError = false,
    TextInputType keyboardType = TextInputType.text,
    void Function(String)? onChanged,
  }) {
    final isDisabled = !enabled || disabled;
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDisabled ? const Color(0xFFF0F2F5) : _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasError ? _primary : _border,
          width: hasError ? 1.5 : 1,
        ),
      ),
      // Center the TextField vertically inside the fixed-height container
      child: Center(
        child: TextField(
          controller: controller,
          enabled: !isDisabled,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 13,
            color: isDisabled ? _inkTertiary : _ink,
            // Prevent font metrics from shifting the baseline
            height: 1.0,
          ),
          // isDense collapses Flutter's default vertical padding so our
          // Center widget can take full control of the alignment.
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          ),
        ),
      ),
    );
  }

  Widget _dropdownTile({
    required String label,
    required bool isEmpty,
    required VoidCallback onTap,
    bool isLoading = false,
    String loadingText = 'Loading...',
    bool disabled = false,
    bool hasError = false,
  }) => GestureDetector(
    onTap: disabled || isLoading ? null : onTap,
    child: Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: disabled ? const Color(0xFFF0F2F5) : _surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasError ? _primary : _border,
          width: hasError ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          if (isLoading) ...[
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: _inkTertiary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              loadingText,
              style: const TextStyle(fontSize: 13, color: _inkTertiary),
            ),
          ] else
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color:
                      disabled
                          ? _inkTertiary
                          : isEmpty
                          ? _inkTertiary
                          : _ink,
                ),
              ),
            ),
          const Spacer(),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: disabled ? _inkTertiary : _inkSecondary,
          ),
        ],
      ),
    ),
  );
}

// ── Generic searchable picker bottom sheet ────────────────────────────────────

class _PickerBottomSheet extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final String? selectedValue;
  final bool searchable;
  final void Function(String label, dynamic value) onSelect;

  const _PickerBottomSheet({
    required this.title,
    required this.items,
    required this.onSelect,
    this.selectedValue,
    this.searchable = false,
  });

  @override
  State<_PickerBottomSheet> createState() => _PickerBottomSheetState();
}

class _PickerBottomSheetState extends State<_PickerBottomSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.items);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    setState(() {
      _filtered =
          q.isEmpty
              ? List.from(widget.items)
              : widget.items
                  .where(
                    (e) => (e['label'] ?? '').toString().toLowerCase().contains(
                      q.toLowerCase(),
                    ),
                  )
                  .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.72;
    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 20, color: _inkTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (widget.searchable) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: _surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearch,
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    hintStyle: TextStyle(color: _inkTertiary, fontSize: 13),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: _inkTertiary,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const Divider(height: 1, color: _border),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final item = _filtered[i];
                final label = item['label']?.toString() ?? '';
                final value = item['value'];
                final isSelected =
                    value.toString() == (widget.selectedValue ?? '');
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSelect(label, value);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                              color: isSelected ? _primary : _ink,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: _primary,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
