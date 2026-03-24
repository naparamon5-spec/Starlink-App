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
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _allUsers = [];

  bool _isLoading = false;
  bool _fetchingMore = false;
  String? _error;

  int _totalItems = 0;
  int _totalPages = 1;
  int _currentPage = 1;
  static const int _pageSize = 10;

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const _primary = Color(0xFFEB1E23);
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
    _loadFirstPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_fetchingMore &&
        _currentPage < _totalPages) {
      _loadNextPage();
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allUsers;
    return _allUsers.where((u) {
      // paginated API uses 'name' and 'code'; detail API uses 'eu_name'/'eu_code'
      final name = (u['eu_name'] ?? u['name'] ?? '').toString().toLowerCase();
      final code = (u['eu_code'] ?? u['code'] ?? '').toString().toLowerCase();
      final customerCode = (u['customer_code'] ?? '').toString().toLowerCase();
      final companyName = (u['company_name'] ?? '').toString().toLowerCase();
      return name.contains(q) ||
          code.contains(q) ||
          customerCode.contains(q) ||
          companyName.contains(q);
    }).toList();
  }

  // ── Parse paginated response ───────────────────────────────────────────────
  // Paginated endpoint returns:
  //   { "data": { "data": [...], "pagination": {...} }, "message": "Success" }
  // After _authorizedGet unwrap → result['data'] = { "data": [...], "pagination": {...} }
  // After _successListResult   → { status, data: [...], pagination: {...} }
  ({int totalPages, int totalItems, List<Map<String, dynamic>> items})
  _parsePage(Map<String, dynamic> response) {
    final rawData = response['data'];
    final List<Map<String, dynamic>> items =
        rawData is List
            ? rawData
                .whereType<Map>()
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                .toList()
            : [];

    final pag = response['pagination'];
    int totalPages = 1;
    int totalItems = 0;
    if (pag is Map) {
      totalPages = int.tryParse(pag['totalPages']?.toString() ?? '1') ?? 1;
      totalItems = int.tryParse(pag['totalItems']?.toString() ?? '0') ?? 0;
    }

    return (totalPages: totalPages, totalItems: totalItems, items: items);
  }

  // ── First page ─────────────────────────────────────────────────────────────
  Future<void> _loadFirstPage() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _allUsers = [];
      _totalItems = 0;
      _totalPages = 1;
      _currentPage = 1;
    });

    try {
      final response = await ApiService.getEndUsersPaginated(
        page: 1,
        limit: _pageSize,
      );
      if (!mounted) return;

      debugPrint(
        'getEndUsersPaginated → status=${response['status']} | dataType=${response['data']?.runtimeType}',
      );

      if (response['status'] != 'success') {
        setState(() {
          _error =
              response['message']?.toString() ?? 'Failed to load end users';
          _isLoading = false;
        });
        return;
      }

      final parsed = _parsePage(response);
      debugPrint(
        'parsed items: ${parsed.items.length} | totalPages: ${parsed.totalPages} | totalItems: ${parsed.totalItems}',
      );
      if (parsed.items.isNotEmpty) {
        debugPrint('first item keys: ${parsed.items.first.keys.toList()}');
        debugPrint('first item: ${parsed.items.first}');
      }

      setState(() {
        _allUsers = parsed.items;
        _totalPages = parsed.totalPages;
        _totalItems = parsed.totalItems;
        _currentPage = 1;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // ── Next page ──────────────────────────────────────────────────────────────
  Future<void> _loadNextPage() async {
    if (_fetchingMore || _currentPage >= _totalPages) return;
    setState(() => _fetchingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final response = await ApiService.getEndUsersPaginated(
        page: nextPage,
        limit: _pageSize,
      );
      if (!mounted) return;

      if (response['status'] == 'success') {
        final parsed = _parsePage(response);

        // Deduplicate — paginated API uses 'code', detail uses 'eu_code'
        final existingCodes = _allUsers.map((u) => _extractCode(u)).toSet();
        final newItems =
            parsed.items
                .where((u) => !existingCodes.contains(_extractCode(u)))
                .toList();

        setState(() {
          _allUsers = [..._allUsers, ...newItems];
          _currentPage = nextPage;
          if (parsed.totalItems > 0) _totalItems = parsed.totalItems;
          if (parsed.totalPages > 0) _totalPages = parsed.totalPages;
        });
      } else {
        setState(() => _currentPage++);
      }
    } catch (_) {
      // Silent — scroll again to retry
    } finally {
      if (mounted) setState(() => _fetchingMore = false);
    }
  }

  /// Extracts the end-user code regardless of which field name the API uses.
  /// Paginated list uses 'code'; detail/search may use 'eu_code'.
  String _extractCode(Map<String, dynamic> user) {
    return [user['eu_code'], user['code'], user['id']]
        .firstWhere(
          (v) => v != null && v.toString().trim().isNotEmpty,
          orElse: () => '',
        )
        .toString()
        .trim();
  }

  /// Extracts the display name regardless of field name.
  String _extractName(Map<String, dynamic> user) {
    return (user['eu_name'] ?? user['name'] ?? '').toString().trim();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _openDetails(Map<String, dynamic> user) {
    final code = _extractCode(user);
    final name = _extractName(user);

    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open: missing end user code'),
          backgroundColor: Color(0xFFEB1E23),
        ),
      );
      return;
    }

    debugPrint('Opening end user detail → code="$code" | name="$name"');

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
    ).then((_) => _loadFirstPage());
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filteredUsers;

    return ColoredBox(
      color: _surface,
      child: Column(
        children: [
          if (!_isLoading) _buildStatsBanner(),

          // Search bar
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
                    vertical: 14,
                    horizontal: 16,
                  ),
                ),
              ),
            ),
          ),

          // List header
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
                    _totalItems > 0 ? '$_totalItems' : '${_allUsers.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ),
                const Spacer(),
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

          // List
          Expanded(
            child:
                _isLoading
                    ? _SkeletonList()
                    : _error != null && _allUsers.isEmpty
                    ? _buildError()
                    : filtered.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: filtered.length + 1,
                      itemBuilder: (context, index) {
                        if (index == filtered.length) {
                          if (_fetchingMore) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: _primary,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }
                          if (_currentPage >= _totalPages &&
                              _allUsers.isNotEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  'All $_totalItems end users loaded',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _inkTertiary,
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox(height: 80);
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
          Column(
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
              Text(
                '$_totalItems',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
            ],
          ),
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
            onPressed: _loadFirstPage,
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

// ── Skeleton shimmer list ──────────────────────────────────────────────────────

class _SkeletonList extends StatefulWidget {
  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  static const _border = Color(0xFFE0E0E0);
  static const _surface = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final opacity = 0.35 + (_anim.value * 0.35);
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          itemCount: 8,
          itemBuilder:
              (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _border.withOpacity(opacity),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 12,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: _border.withOpacity(opacity),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 10,
                              width: 160,
                              decoration: BoxDecoration(
                                color: _border.withOpacity(opacity),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  height: 16,
                                  width: 70,
                                  decoration: BoxDecoration(
                                    color: _border.withOpacity(opacity),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  height: 16,
                                  width: 90,
                                  decoration: BoxDecoration(
                                    color: _border.withOpacity(opacity),
                                    borderRadius: BorderRadius.circular(5),
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
              ),
        );
      },
    );
  }
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
  static const _border = Color(0xFFE0E0E0);

  const _EndUserCard({required this.user, required this.onTap});

  // FIX: paginated API uses 'code', detail API uses 'eu_code' — check both
  String get _euCode =>
      (user['eu_code'] ?? user['code'] ?? '').toString().trim();
  String get _customerCode => (user['customer_code'] ?? '').toString().trim();
  // FIX: paginated API uses 'name', detail API uses 'eu_name' — check both
  String get _name => (user['eu_name'] ?? user['name'] ?? '').toString().trim();
  String get _companyName => (user['company_name'] ?? '').toString().trim();
  bool get _isActive =>
      (user['inactive'] ?? 'N').toString().toUpperCase() == 'N';

  String get _initials {
    final n = _name.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
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
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + status badge
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
                    if (_companyName.isNotEmpty) ...[
                      const SizedBox(height: 2),
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
                    ],
                    const SizedBox(height: 4),
                    // Code tags
                    Row(
                      children: [
                        if (_euCode.isNotEmpty) ...[
                          _MetaTag(label: 'EU', value: _euCode),
                          const SizedBox(width: 6),
                        ],
                        // if (_customerCode.isNotEmpty)
                        //   _MetaTag(label: 'Customer', value: _customerCode),
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
