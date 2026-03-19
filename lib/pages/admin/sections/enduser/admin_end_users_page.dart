import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../services/api_service.dart';
import 'admin_end_user_details_page.dart';
import 'admin_create_end_user_page.dart';

class AdminEndUsersPage extends StatefulWidget {
  const AdminEndUsersPage({super.key});

  @override
  State<AdminEndUsersPage> createState() => _AdminEndUsersPageState();
}

class _AdminEndUsersPageState extends State<AdminEndUsersPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  // Master list of ALL end users fetched across all pages
  List<Map<String, dynamic>> _allUsers = [];

  bool _isLoading = false;
  bool _fetchingMore = false;
  String? _error;

  // Pagination
  int _totalItems = 0;
  int _totalPages = 1;
  static const int _pageSize = 50;

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const _primary = Color(0xFFEB1E23);
  static const _primaryDark = Color(0xFF760F12);
  static const _success = Color(0xFF24A148);
  static const _ink = Color(0xFF000000);
  static const _inkSecondary = Color(0xFF6F6F6F);
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Client-side search filter ──────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredUsers {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allUsers;
    return _allUsers.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final code = (u['code'] ?? '').toString().toLowerCase();
      final customerCode = (u['customer_code'] ?? '').toString().toLowerCase();
      final companyName = (u['company_name'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          code.contains(q) ||
          customerCode.contains(q) ||
          companyName.contains(q);
    }).toList();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadUsers() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _allUsers = [];
      _totalItems = 0;
      _totalPages = 1;
    });

    try {
      // Page 1
      final response = await ApiService.getEndUsersPaginated(
        page: 1,
        limit: _pageSize,
      );

      if (!mounted) return;

      if (response['status'] != 'success') {
        setState(() {
          _error =
              response['message']?.toString() ?? 'Failed to load end users';
          _isLoading = false;
        });
        return;
      }

      // Parse pagination from raw response
      // Shape: { data: { data: [...], pagination: { totalPages, totalItems } } }
      final raw = response['raw'];
      int totalPages = 1;
      int totalItems = 0;
      if (raw is Map) {
        final wrapper = raw['data'];
        if (wrapper is Map) {
          final pagination = wrapper['pagination'];
          if (pagination is Map) {
            totalPages =
                int.tryParse(pagination['totalPages']?.toString() ?? '1') ?? 1;
            totalItems =
                int.tryParse(pagination['totalItems']?.toString() ?? '0') ?? 0;
          }
        }
      }

      final page1Items = _parseList(response['data']);

      setState(() {
        _allUsers = page1Items;
        _totalPages = totalPages;
        _totalItems = totalItems;
        _isLoading = false;
      });

      // Fetch remaining pages in background
      if (totalPages > 1) {
        _fetchRemainingPages(totalPages);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchRemainingPages(int totalPages) async {
    if (!mounted) return;
    setState(() => _fetchingMore = true);

    try {
      for (int page = 2; page <= totalPages; page++) {
        if (!mounted) break;

        final response = await ApiService.getEndUsersPaginated(
          page: page,
          limit: _pageSize,
        );

        if (!mounted) break;

        if (response['status'] == 'success') {
          final items = _parseList(response['data']);
          if (mounted && items.isNotEmpty) {
            setState(() {
              final existingCodes =
                  _allUsers.map((u) => u['code'].toString()).toSet();
              final newItems =
                  items
                      .where(
                        (u) => !existingCodes.contains(u['code'].toString()),
                      )
                      .toList();
              _allUsers = [..._allUsers, ...newItems];
            });
          }
        }
      }
    } catch (_) {
      // Silently ignore background errors — page 1 is already shown
    } finally {
      if (mounted) setState(() => _fetchingMore = false);
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic data) {
    if (data is List) {
      return data
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _openDetails(Map<String, dynamic> user) {
    final code = (user['customer_code'] ?? user['code'] ?? '').toString();
    final name = (user['name'] ?? '').toString();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AdminEndUserDetailsPage(
              endUserId: code,
              endUserCode: code,
              endUserName: name,
            ),
      ),
    );
  }

  void _openCreateEndUser() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminCreateEndUserPage()),
    ).then((_) => _loadUsers());
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;

    return ColoredBox(
      color: _surface,
      child: Column(
        children: [
          // ── Hero stats banner ────────────────────────────────────────────
          if (!_isLoading) _buildStatsBanner(),

          // ── Search bar ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: _surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 250),
                    () {
                      if (mounted) setState(() {});
                    },
                  );
                },
                style: const TextStyle(fontSize: 13, color: _ink),
                decoration: InputDecoration(
                  hintText: 'Search by name, code, company…',
                  hintStyle: const TextStyle(fontSize: 13, color: _inkTertiary),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: _inkTertiary,
                  ),
                  suffixIcon:
                      _searchController.text.isNotEmpty
                          ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: _inkTertiary,
                            ),
                          )
                          : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                ),
              ),
            ),
          ),

          // ── List header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
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
                    '${filtered.length}${_fetchingMore ? '+' : ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ),
                if (_fetchingMore) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      color: _primary,
                      strokeWidth: 1.5,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${_allUsers.length} / $_totalItems',
                    style: const TextStyle(fontSize: 11, color: _inkTertiary),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: _loadUsers,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: _inkTertiary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _openCreateEndUser,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 15, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Create',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── List ─────────────────────────────────────────────────────────
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: _primary,
                              strokeWidth: 2.5,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Loading end users…',
                            style: TextStyle(
                              fontSize: 13,
                              color: _inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                    : _error != null && _allUsers.isEmpty
                    ? _buildError()
                    : filtered.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: filtered.length + (_fetchingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Bottom loading row
                        if (index == filtered.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      color: _primary,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Loading all end users… '
                                    '(${_allUsers.length} of $_totalItems)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _inkTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final user = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: RepaintBoundary(
                            child: _EndUserCard(
                              user: user,
                              onTap: () => _openDetails(user),
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

  // ── Stats banner ───────────────────────────────────────────────────────────

  Widget _buildStatsBanner() {
    final total = _totalItems > 0 ? _totalItems : _allUsers.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEB1E23), Color(0xFF760F12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.people_alt_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total End Users',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                    if (_fetchingMore && _allUsers.length < total) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '(${_allUsers.length} loaded)',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_fetchingMore) ...[
            const SizedBox(width: 10),
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                color: Colors.white54,
                strokeWidth: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: _primary,
              size: 24,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: _inkSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try again'),
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmpty() => Center(
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
          style: TextStyle(fontSize: 14, color: _inkSecondary),
        ),
      ],
    ),
  );
}

// ── End user card ──────────────────────────────────────────────────────────────

class _EndUserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap;

  static const _primary = Color(0xFFEB1E23);
  static const _success = Color(0xFF24A148);
  static const _ink = Color(0xFF000000);
  static const _inkSecondary = Color(0xFF6F6F6F);
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

  const _EndUserCard({required this.user, required this.onTap});

  String get _name => (user['name'] ?? '').toString().trim();
  String get _code => (user['code'] ?? '').toString().trim();
  String get _customerCode => (user['customer_code'] ?? '').toString().trim();
  String get _companyName => (user['company_name'] ?? '').toString().trim();
  bool get _isActive =>
      (user['inactive'] ?? 'N').toString().toUpperCase() == 'N';

  String get _initials {
    final parts = _name.trim().split(RegExp(r'\s+'));
    if (_name.trim().isEmpty) return '?';
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
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
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

              // Name + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _name.isEmpty ? '—' : _name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Active / Inactive badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _isActive
                                    ? _success.withOpacity(0.1)
                                    : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color:
                                  _isActive ? _success : Colors.grey.shade500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Company name
                    if (_companyName.isNotEmpty)
                      Text(
                        _companyName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _inkSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    // Code row
                    Row(
                      children: [
                        if (_code.isNotEmpty) ...[
                          _MetaTag(label: 'ID', value: _code),
                          const SizedBox(width: 6),
                        ],
                        if (_customerCode.isNotEmpty)
                          _MetaTag(label: 'Customer', value: _customerCode),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
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

class _MetaTag extends StatelessWidget {
  final String label, value;
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

  const _MetaTag({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: _surfaceSubtle,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: _border),
    ),
    child: Text(
      '$label: $value',
      style: const TextStyle(
        fontSize: 9,
        color: _inkTertiary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
