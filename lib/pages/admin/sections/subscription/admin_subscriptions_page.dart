import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../services/api_service.dart';
import 'admin_subscription_details_page.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _success = Color(0xFF24A148);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);

class AdminSubscriptionsPage extends StatefulWidget {
  const AdminSubscriptionsPage({super.key});

  @override
  State<AdminSubscriptionsPage> createState() => _AdminSubscriptionsPageState();
}

class _AdminSubscriptionsPageState extends State<AdminSubscriptionsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _allSubscriptions = [];

  bool _loading = false;
  bool _fetchingMore = false;
  String? _error;

  int _totalItems = 0;
  int _totalPages = 1;
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
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

  List<Map<String, dynamic>> get _filteredSubscriptions {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allSubscriptions;
    return _allSubscriptions.where((s) {
      final nickname = (s['nickname'] ?? '').toString().toLowerCase();
      final id = (s['id'] ?? '').toString().toLowerCase();
      final sln = (s['serviceLineNumber'] ?? '').toString().toLowerCase();
      final plan = (s['subscriptionPlan'] ?? '').toString().toLowerCase();
      final eu =
          (s['end_user_name'] ?? s['company_name'] ?? '')
              .toString()
              .toLowerCase();
      return nickname.contains(q) ||
          id.contains(q) ||
          sln.contains(q) ||
          plan.contains(q) ||
          eu.contains(q);
    }).toList();
  }

  // ── Parse ──────────────────────────────────────────────────────────────────

  ({int totalPages, int totalItems, List<Map<String, dynamic>> items})
  _parsePage(Map<String, dynamic> response) {
    final data = response['data'];
    final List<Map<String, dynamic>> items =
        data is List
            ? data
                .whereType<Map>()
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                .toList()
            : [];

    final pagination = response['pagination'];
    int totalPages = 1;
    int totalItems = 0;
    if (pagination is Map) {
      totalPages =
          int.tryParse(
            (pagination['totalPages'] ?? pagination['total_pages'] ?? 1)
                .toString(),
          ) ??
          1;
      totalItems =
          int.tryParse(
            (pagination['totalItems'] ?? pagination['total_items'] ?? 0)
                .toString(),
          ) ??
          0;
    }

    return (totalPages: totalPages, totalItems: totalItems, items: items);
  }

  // ── First page ─────────────────────────────────────────────────────────────

  Future<void> _loadFirstPage() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _allSubscriptions = [];
      _totalItems = 0;
      _totalPages = 1;
      _currentPage = 1;
    });

    try {
      final response = await ApiService.getSubscriptionsPaginated(
        page: 1,
        limit: _pageSize,
        search: '',
      );
      if (!mounted) return;

      if (response['status'] != 'success') {
        setState(() {
          _error =
              response['message']?.toString() ?? 'Failed to load subscriptions';
          _loading = false;
        });
        return;
      }

      final parsed = _parsePage(response);

      setState(() {
        _allSubscriptions = parsed.items;
        _totalPages = parsed.totalPages;
        _totalItems = parsed.totalItems;
        _currentPage = 1;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  // ── Next page ──────────────────────────────────────────────────────────────

  Future<void> _loadNextPage() async {
    if (_fetchingMore || _currentPage >= _totalPages) return;
    setState(() => _fetchingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final response = await ApiService.getSubscriptionsPaginated(
        page: nextPage,
        limit: _pageSize,
        search: '',
      );
      if (!mounted) return;

      if (response['status'] == 'success') {
        final parsed = _parsePage(response);
        final existingIds =
            _allSubscriptions.map((s) => s['id'].toString()).toSet();
        final newItems =
            parsed.items
                .where((s) => !existingIds.contains(s['id'].toString()))
                .toList();

        setState(() {
          _allSubscriptions = [..._allSubscriptions, ...newItems];
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

  void _openDetails(Map<String, dynamic> sub) {
    final serviceLineNumber = sub['serviceLineNumber']?.toString() ?? '';
    final nickname = sub['nickname']?.toString() ?? '';
    if (serviceLineNumber.trim().isEmpty || serviceLineNumber == '—') return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => AdminSubscriptionDetailsPage(
              serviceLineNumber: serviceLineNumber.trim(),
              title:
                  nickname.trim().isNotEmpty
                      ? nickname.trim()
                      : serviceLineNumber.trim(),
            ),
      ),
    );
  }

  Color _activeColor(String? active) {
    final a = (active ?? '').toString().toUpperCase();
    if (a == 'ACTIVE') return _success;
    if (a == 'EXPIRED' || a == 'CANCELLED') return _primaryDark;
    return _inkTertiary;
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == '0000-00-00') return '—';
    return raw;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSubscriptions;

    return ColoredBox(
      color: _surface,
      child: Column(
        children: [
          // Stats banner
          if (!_loading) _buildStatsBanner(),

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
                  hintText: 'Search subscriptions…',
                  hintStyle: const TextStyle(color: _inkTertiary, fontSize: 13),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _inkTertiary,
                    size: 18,
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
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Subscriptions',
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
                    _totalItems > 0
                        ? '$_totalItems'
                        : '${_allSubscriptions.length}',
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
              ],
            ),
          ),

          Container(height: 1, color: _border),

          // List
          Expanded(
            child:
                _loading
                    ? _SkeletonList()
                    : _error != null && _allSubscriptions.isEmpty
                    ? _buildError()
                    : filtered.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                              _allSubscriptions.isNotEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  'All $_totalItems subscriptions loaded',
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
                        final sub = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: RepaintBoundary(
                            child: _SubscriptionCard(
                              sub: sub,
                              onTap: () => _openDetails(sub),
                              activeColor: _activeColor(
                                sub['active']?.toString(),
                              ),
                              formattedStart: _formatDate(
                                sub['startDate']?.toString(),
                              ),
                              formattedEnd: _formatDate(
                                sub['endDate']?.toString(),
                              ),
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
              Icons.subscriptions_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Subscriptions',
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
          const SizedBox(height: 14),
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
            Icons.subscriptions_outlined,
            color: _inkTertiary,
            size: 24,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'No subscriptions found.',
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: 6,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _border.withOpacity(opacity),
                          borderRadius: BorderRadius.circular(12),
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
                              width: 180,
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
                                  width: 60,
                                  decoration: BoxDecoration(
                                    color: _border.withOpacity(opacity),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              height: 1,
                              color: _border.withOpacity(opacity),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 10,
                              width: 160,
                              decoration: BoxDecoration(
                                color: _border.withOpacity(opacity),
                                borderRadius: BorderRadius.circular(6),
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

// ── Subscription card ──────────────────────────────────────────────────────────

class _SubscriptionCard extends StatelessWidget {
  final Map<String, dynamic> sub;
  final VoidCallback onTap;
  final Color activeColor;
  final String formattedStart;
  final String formattedEnd;

  static const _primary = Color(0xFFEB1E23);
  static const _ink = Color(0xFF000000);
  static const _inkSecondary = Color(0xFF6F6F6F);
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

  const _SubscriptionCard({
    required this.sub,
    required this.onTap,
    required this.activeColor,
    required this.formattedStart,
    required this.formattedEnd,
  });

  String get _nickname => (sub['nickname'] ?? '—').toString();
  String get _id => (sub['id'] ?? '—').toString();
  String get _serviceLineNumber => (sub['serviceLineNumber'] ?? '—').toString();
  String get _active => (sub['active'] ?? '—').toString();
  String get _subscriptionPlan => (sub['subscriptionPlan'] ?? '—').toString();
  String get _dataplan => (sub['dataplan'] ?? '—').toString();
  String get _endUserName =>
      (sub['end_user_name'] ?? sub['company_name'] ?? '').toString();
  bool get _canNavigate =>
      _serviceLineNumber.trim().isNotEmpty && _serviceLineNumber != '—';

  @override
  Widget build(BuildContext context) {
    final initial = _nickname.isNotEmpty ? _nickname[0].toUpperCase() : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _canNavigate ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _nickname,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: _ink,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: activeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _active,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: activeColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'ID: $_id · $_serviceLineNumber',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _inkSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (_subscriptionPlan != '—')
                            _MetaTag(label: 'Plan', value: _subscriptionPlan),
                          if (_dataplan != '—')
                            _MetaTag(label: 'Data', value: '$_dataplan GB'),
                        ],
                      ),
                      if (_endUserName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          _endUserName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _inkTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(height: 1, color: _border),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 11,
                            color: _inkTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$formattedStart → $formattedEnd',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _inkTertiary,
                            ),
                          ),
                          const Spacer(),
                          if (_canNavigate)
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: _inkTertiary,
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
      ),
    );
  }
}

// ── Meta tag ───────────────────────────────────────────────────────────────────

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
