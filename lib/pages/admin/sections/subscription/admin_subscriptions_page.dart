import 'package:flutter/material.dart';
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

  List<Map<String, dynamic>> _allSubscriptions = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = false;
  String? _error;
  int _totalItems = 0;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered =
          q.isEmpty
              ? _allSubscriptions
              : _allSubscriptions.where((s) {
                final nickname = (s['nickname'] ?? '').toString().toLowerCase();
                final id = (s['id'] ?? '').toString().toLowerCase();
                final sln =
                    (s['serviceLineNumber'] ?? '').toString().toLowerCase();
                final plan =
                    (s['subscriptionPlan'] ?? '').toString().toLowerCase();
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
    });
  }

  Future<void> _loadSubscriptions() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _allSubscriptions = [];
      _filtered = [];
      _totalItems = 0;
    });

    try {
      const int pageSize = 50;
      int page = 1;
      int totalPages = 1;
      final List<Map<String, dynamic>> all = [];

      do {
        final response = await ApiService.getSubscriptionsPaginated(
          page: page,
          limit: pageSize,
          search: '',
        );

        if (!mounted) return;

        if (response['status'] != 'success') {
          setState(() {
            _loading = false;
            _error =
                response['message']?.toString() ??
                'Failed to load subscriptions';
          });
          return;
        }

        final data = response['data'];
        final List<dynamic> items = data is List ? data : [];
        all.addAll(
          items.whereType<Map>().map<Map<String, dynamic>>(
            (e) => Map<String, dynamic>.from(e),
          ),
        );

        final pagination = response['pagination'];
        if (pagination is Map<String, dynamic>) {
          totalPages =
              (pagination['totalPages'] ?? pagination['total_pages'] ?? 1)
                  as int;
          _totalItems =
              (pagination['totalItems'] ?? pagination['total_items'] ?? 0)
                  as int;
        }

        // Show first page immediately
        if (page == 1 && mounted) {
          setState(() {
            _allSubscriptions = List.from(all);
            _filtered = List.from(all);
          });
        }

        page++;
      } while (page <= totalPages);

      if (!mounted) return;
      setState(() {
        _allSubscriptions = all;
        _filtered = all;
        _totalItems = all.length > _totalItems ? all.length : _totalItems;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final total = _totalItems > 0 ? _totalItems : _allSubscriptions.length;

    return ColoredBox(
      color: _surface,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── Pinned header ──────────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(child: _buildStickyHeader(total)),
          ),

          // ── Body ──────────────────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        color: _primary,
                        strokeWidth: 2.5,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Loading subscriptions…',
                      style: TextStyle(fontSize: 13, color: _inkSecondary),
                    ),
                  ],
                ),
              ),
            )
          else if (_error != null && _allSubscriptions.isEmpty)
            SliverFillRemaining(child: _buildError())
          else if (_filtered.isEmpty)
            SliverFillRemaining(child: _buildEmpty())
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final sub = _filtered[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RepaintBoundary(
                      child: _SubscriptionCard(
                        sub: sub,
                        onTap: () => _openDetails(sub),
                        activeColor: _activeColor(sub['active']?.toString()),
                        formattedStart: _formatDate(
                          sub['startDate']?.toString(),
                        ),
                        formattedEnd: _formatDate(sub['endDate']?.toString()),
                      ),
                    ),
                  );
                }, childCount: _filtered.length),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ],
      ),
    );
  }

  // ── Sticky header ──────────────────────────────────────────────────────────

  Widget _buildStickyHeader(int total) {
    return ColoredBox(
      color: _surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: _surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => _onSearch(),
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
                              _onSearch();
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

          // List title row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 10),
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
                    '$total',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _loadSubscriptions,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: _inkTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(height: 1, color: _border),
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
            onPressed: _loadSubscriptions,
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

// ── Sticky header delegate ─────────────────────────────────────────────────────

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  // search(16+44+0) + title(12+36+10) + divider(1) = 119
  static const double _height = 120.0;

  const _StickyHeaderDelegate({required this.child});

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox(height: _height, child: child);

  @override
  bool shouldRebuild(_StickyHeaderDelegate old) => true;
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
  String get _address => (sub['address'] ?? '').toString();
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
                // Avatar
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

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nickname + status badge
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

                      // ID + service line
                      Text(
                        'ID: $_id · $_serviceLineNumber',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _inkSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      // Meta tags row
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

                      // Footer: dates + chevron
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
