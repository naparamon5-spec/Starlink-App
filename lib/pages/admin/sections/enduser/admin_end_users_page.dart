import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';
import 'admin_end_user_details_page.dart';

class AdminEndUsersPage extends StatefulWidget {
  const AdminEndUsersPage({super.key});

  @override
  State<AdminEndUsersPage> createState() => _AdminEndUsersPageState();
}

class _AdminEndUsersPageState extends State<AdminEndUsersPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _endUsers = [];
  String _searchQuery = '';
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  bool _isLoading = false;
  late AnimationController _animController;

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const _primary = Color(0xFFEB1E23); // Brand red
  static const _primaryDark = Color(0xFF760F12); // Dark red
  static const _success = Color(0xFF24A148);
  static const _danger = Color(0xFFEB1E23);
  static const _ink = Color(0xFF000000);
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
      duration: const Duration(milliseconds: 500),
    );
    _loadUsers();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({int page = 1}) async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.getEndUsersPaginated(
        page: page,
        limit: 10,
        search: _searchQuery,
      );

      if (!mounted) return;

      if (response['status'] == 'success') {
        final payload = response['data'];
        final items = payload is Map ? payload['data'] : null;
        final pagination = payload is Map ? payload['pagination'] : null;

        setState(() {
          _endUsers =
              items is List
                  ? List<Map<String, dynamic>>.from(
                    items.whereType<Map>().map(
                      (e) => Map<String, dynamic>.from(e),
                    ),
                  )
                  : [];
          _currentPage = (pagination?['currentPage'] ?? 1) as int;
          _totalPages = (pagination?['totalPages'] ?? 1) as int;
          _totalItems = (pagination?['totalItems'] ?? 0) as int;
        });
        _animController.forward(from: 0);
      }
    } catch (e) {
      debugPrint('Error loading end users: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _openDetails(Map<String, dynamic> user) {
    final euCode =
        (user['eu_code'] ?? user['code'] ?? user['id'] ?? '').toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AdminEndUserDetailsPage(
              endUserId: euCode,
              endUserCode: euCode,
              endUserName: (user['name'] ?? '').toString(),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _surface,
      child: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                _searchQuery = val;
                _loadUsers(page: 1);
              },
              style: const TextStyle(fontSize: 13, color: _ink),
              decoration: InputDecoration(
                hintText: 'Search by name or code…',
                hintStyle: const TextStyle(fontSize: 13, color: _inkTertiary),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: _inkTertiary,
                ),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _loadUsers(page: 1);
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: _inkTertiary,
                          ),
                        )
                        : null,
                filled: true,
                fillColor: _surfaceSubtle,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primary, width: 1.5),
                ),
              ),
            ),
          ),

          // ── Section header ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                const Text(
                  'End Users',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),
                if (!_isLoading)
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
                      '$_totalItems',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _loadUsers(page: _currentPage),
                  child: const Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: _inkTertiary,
                  ),
                ),
              ],
            ),
          ),

          // ── List ───────────────────────────────────────────────────────────
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          color: _primary,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                    : _endUsers.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              color: _surfaceSubtle,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.people_outline_rounded,
                              color: _inkTertiary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No end users found',
                            style: TextStyle(
                              fontSize: 14,
                              color: _inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _endUsers.length,
                      itemBuilder: (context, index) {
                        final user = _endUsers[index];
                        final name = (user['name'] ?? '').toString();
                        final code =
                            (user['code'] ?? user['eu_code'] ?? '').toString();
                        final inactive = (user['inactive'] ?? 'Y').toString();
                        final isActive = inactive == 'N';

                        return AnimatedBuilder(
                          animation: _animController,
                          builder: (context, child) {
                            final delay = index * 0.06;
                            final t = (_animController.value - delay).clamp(
                              0.0,
                              1.0,
                            );
                            return Opacity(
                              opacity: t,
                              child: Transform.translate(
                                offset: Offset(0, 12 * (1 - t)),
                                child: child,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _EndUserCard(
                              name: name,
                              code: code,
                              isActive: isActive,
                              onTap: () => _openDetails(user),
                            ),
                          ),
                        );
                      },
                    ),
          ),

          // ── Pagination ─────────────────────────────────────────────────────
          if (_totalPages > 1 && !_isLoading)
            Container(
              decoration: const BoxDecoration(
                color: _surface,
                border: Border(top: BorderSide(color: _border)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _PaginationButton(
                    label: 'Previous',
                    icon: Icons.chevron_left_rounded,
                    enabled: _currentPage > 1,
                    onTap: () => _loadUsers(page: _currentPage - 1),
                  ),
                  Text(
                    'Page $_currentPage of $_totalPages',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _inkSecondary,
                    ),
                  ),
                  _PaginationButton(
                    label: 'Next',
                    icon: Icons.chevron_right_rounded,
                    iconTrailing: true,
                    enabled: _currentPage < _totalPages,
                    onTap: () => _loadUsers(page: _currentPage + 1),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _EndUserCard extends StatelessWidget {
  final String name;
  final String code;
  final bool isActive;
  final VoidCallback onTap;

  static const _primary = Color(0xFFEB1E23);
  static const _primaryDark = Color(0xFF760F12);
  static const _success = Color(0xFF24A148);
  static const _ink = Color(0xFF000000);
  static const _inkSecondary = Color(0xFF6F6F6F);
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

  const _EndUserCard({
    required this.name,
    required this.code,
    required this.isActive,
    required this.onTap,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (name.trim().isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── Avatar ───────────────────────────────────────────────
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // ── Name + code ──────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? '—' : name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Code: $code',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _inkSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Status badge ─────────────────────────────────────────
              _StatusBadge(isActive: isActive),
              const SizedBox(width: 6),

              // ── Chevron ──────────────────────────────────────────────
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: _inkTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    // Active = green, Inactive = dark red
    final color = isActive ? const Color(0xFF24A148) : const Color(0xFF760F12);
    final label = isActive ? 'Active' : 'Inactive';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final bool iconTrailing;
  final VoidCallback onTap;

  const _PaginationButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.iconTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFEB1E23);
    const inkTertiary = Color(0xFFA8A8A8);
    const surfaceSubtle = Color(0xFFF4F4F4);
    const border = Color(0xFFE0E0E0);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? primary.withOpacity(0.06) : surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? primary.withOpacity(0.2) : border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!iconTrailing) ...[
              Icon(icon, size: 16, color: enabled ? primary : inkTertiary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: enabled ? primary : inkTertiary,
              ),
            ),
            if (iconTrailing) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 16, color: enabled ? primary : inkTertiary),
            ],
          ],
        ),
      ),
    );
  }
}
