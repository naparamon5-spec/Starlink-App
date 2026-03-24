import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../services/api_service.dart';
import 'admin_agent_details_page.dart';
import 'admin_create_agent_page.dart';

class AdminAgentsPage extends StatefulWidget {
  const AdminAgentsPage({super.key});

  @override
  State<AdminAgentsPage> createState() => _AdminAgentsPageState();
}

class _AdminAgentsPageState extends State<AdminAgentsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _agents = [];

  bool _isLoading = false;
  bool _fetchingMore = false;
  String? _error;

  int _totalItems = 0;
  int _totalPages = 1;
  int _currentPage = 1;
  static const int _pageSize = 10;

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

  List<Map<String, dynamic>> get _filteredAgents {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _agents;
    return _agents.where((a) {
      final name = (a['name'] ?? '').toString().toLowerCase();
      final code = (a['code'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();
  }

  // ── Parse response ─────────────────────────────────────────────────────────
  ({int totalPages, int totalItems, List<Map<String, dynamic>> items})
  _parsePage(Map<String, dynamic> response) {
    final data = response['data'];

    // Items may be nested under data['data'] or be the flat list directly
    final rawList =
        (data is Map && data['data'] is List)
            ? data['data'] as List
            : (data is List ? data : []);

    final List<Map<String, dynamic>> items =
        rawList.whereType<Map>().map<Map<String, dynamic>>((e) {
          final c = Map<String, dynamic>.from(e);
          final name = (c['name'] ?? 'Agent').toString();
          final code = (c['code'] ?? '').toString();
          final id = (c['id'] ?? c['customer_id'] ?? '').toString();
          final inactiveRaw = (c['inactive'] ?? 'N').toString();
          return {
            'id': id,
            'name': name,
            'code': code,
            'inactive': inactiveRaw,
            'avatar': _initials(name),
          };
        }).toList();

    // Pagination may be nested under data['pagination'] or top-level
    final pag =
        (data is Map && data['pagination'] != null)
            ? data['pagination']
            : response['pagination'];

    int totalPages = 1;
    int totalItems = 0;
    if (pag is Map) {
      totalPages = int.tryParse(pag['totalPages']?.toString() ?? '1') ?? 1;
      totalItems = int.tryParse(pag['totalItems']?.toString() ?? '0') ?? 0;
    }

    return (totalPages: totalPages, totalItems: totalItems, items: items);
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || name.trim().isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  // ── First page ─────────────────────────────────────────────────────────────
  Future<void> _loadFirstPage() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _agents = [];
      _totalItems = 0;
      _totalPages = 1;
      _currentPage = 1;
    });

    try {
      final response = await ApiService.getCustomersPaginated(
        page: 1,
        limit: _pageSize,
        search: _searchController.text.trim(),
      );
      if (!mounted) return;

      final data = response['data'];
      if (data == null) {
        setState(() {
          _error = response['message']?.toString() ?? 'Failed to load agents';
          _isLoading = false;
        });
        return;
      }

      final parsed = _parsePage(response);

      setState(() {
        _agents = parsed.items;
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

  // ── Next page — completely silent ──────────────────────────────────────────
  Future<void> _loadNextPage() async {
    if (_fetchingMore || _currentPage >= _totalPages) return;
    setState(() => _fetchingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final response = await ApiService.getCustomersPaginated(
        page: nextPage,
        limit: _pageSize,
        search: _searchController.text.trim(),
      );
      if (!mounted) return;

      final data = response['data'];
      if (data != null) {
        final parsed = _parsePage(response);
        final existingIds = _agents.map((a) => a['id'].toString()).toSet();
        final newItems =
            parsed.items
                .where((a) => !existingIds.contains(a['id'].toString()))
                .toList();

        setState(() {
          _agents = [..._agents, ...newItems];
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

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _openDetails(Map<String, dynamic> agent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AdminAgentDetailsPage(
              agentId: agent['id'].toString(),
              agentCode: agent['code'].toString(),
              agentName: agent['name'].toString(),
            ),
      ),
    );
  }

  Future<void> _openCreateAgent() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdminCreateAgentPage()),
    );
    if (created == true) _loadFirstPage();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAgents;

    return ColoredBox(
      color: _surface,
      child: Column(
        children: [
          // Stats banner — shows totalItems immediately from page 1
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
                  hintText: 'Search by name or code…',
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
                  'Agents',
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
                    _totalItems > 0 ? '$_totalItems' : '${_agents.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ),
                const Spacer(),
                // GestureDetector(
                //   onTap: _loadFirstPage,
                //   child: const Padding(
                //     padding: EdgeInsets.symmetric(horizontal: 8),
                //     child: Icon(
                //       Icons.refresh_rounded,
                //       size: 18,
                //       color: _inkTertiary,
                //     ),
                //   ),
                // ),
                GestureDetector(
                  onTap: _openCreateAgent,
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
                          'Add Agent',
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
                    : _error != null && _agents.isEmpty
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
                              _agents.isNotEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  'All $_totalItems agents loaded',
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
                        final agent = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: RepaintBoundary(
                            child: _AgentCard(
                              agent: agent,
                              onTap: () => _openDetails(agent),
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
              Icons.support_agent_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Agents',
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
            Icons.support_agent_outlined,
            color: _inkTertiary,
            size: 24,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'No agents found',
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
                            Container(
                              height: 16,
                              width: 70,
                              decoration: BoxDecoration(
                                color: _border.withOpacity(opacity),
                                borderRadius: BorderRadius.circular(5),
                              ),
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

// ── Agent card ─────────────────────────────────────────────────────────────────

class _AgentCard extends StatelessWidget {
  final Map<String, dynamic> agent;
  final VoidCallback onTap;

  static const _primary = Color(0xFFEB1E23);
  static const _success = Color(0xFF24A148);
  static const _primaryDark = Color(0xFF760F12);
  static const _ink = Color(0xFF000000);
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

  const _AgentCard({required this.agent, required this.onTap});

  String get _name => (agent['name'] ?? '').toString().trim();
  String get _code => (agent['code'] ?? '').toString().trim();
  String get _avatar => (agent['avatar'] ?? '?').toString();
  bool get _isActive =>
      (agent['inactive'] ?? 'N').toString().toUpperCase() == 'N';

  @override
  Widget build(BuildContext context) {
    final statusColor = _isActive ? _success : _primaryDark;

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
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _avatar,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: _surface, width: 2),
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
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (_code.isNotEmpty) _MetaTag(label: 'Code', value: _code),
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
