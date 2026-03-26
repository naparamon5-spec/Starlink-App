import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../../services/api_service.dart';
import 'customer_subscription_detail_page.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _activeGreen = Color(0xFF00C48C);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);

/// Robust active-status resolver.
bool _isActiveSub(Map<String, dynamic> sub) {
  for (final key in ['active', 'is_active', 'isActive', 'status', 'state']) {
    final raw = sub[key];
    if (raw == null) continue;
    if (raw is bool) return raw;
    if (raw is int) return raw == 1;
    final s = raw.toString().toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'active' || s == 'enabled') {
      return true;
    }
    if (s == 'false' ||
        s == '0' ||
        s == 'inactive' ||
        s == 'disabled' ||
        s == 'expired') {
      return false;
    }
  }
  return false;
}

/// Extract service line number — handles both camelCase and snake_case.
String _sln(Map<String, dynamic> sub) =>
    (sub['serviceLineNumber'] ?? sub['service_line_number'] ?? '')
        .toString()
        .trim();

/// Extract nickname / display name.
String _nickname(Map<String, dynamic> sub) =>
    (sub['nickname'] ?? sub['name'] ?? '').toString().trim();

/// Extract end date — handles endDate, end_date, expires_at, expiry_date.
String _endDate(Map<String, dynamic> sub) =>
    (sub['endDate'] ??
            sub['end_date'] ??
            sub['expires_at'] ??
            sub['expiry_date'] ??
            '')
        .toString()
        .trim();

class CustomerSubscriptionPage extends StatefulWidget {
  final bool showAppBar;

  const CustomerSubscriptionPage({super.key, this.showAppBar = true});

  @override
  State<CustomerSubscriptionPage> createState() =>
      _CustomerSubscriptionPageState();
}

class _CustomerSubscriptionPageState extends State<CustomerSubscriptionPage> {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _loading = false;
  bool _fetchingMore = false;
  String? _error;

  String? _euCode;
  String? _customerCode;
  String? _role;

  List<Map<String, dynamic>> _allSubscriptions = [];
  int _totalItems = 0;
  int _totalPages = 1;
  int _currentPage = 1;
  static const int _pageSize = 10;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  final ScrollController _scrollController = ScrollController();

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 250), () {
        if (mounted) setState(() {});
      });
    });
    _init();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
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

  // ── Filtering ──────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filtered {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allSubscriptions;
    return _allSubscriptions.where((sub) {
      final n = _nickname(sub).toLowerCase();
      final s = _sln(sub).toLowerCase();
      final status = _isActiveSub(sub) ? 'active' : 'inactive';
      final ed = _endDate(sub).toLowerCase();
      final company = (sub['company_name'] ?? '').toString().toLowerCase();
      final endUser = (sub['end_user_name'] ?? '').toString().toLowerCase();
      return n.contains(q) ||
          s.contains(q) ||
          status.contains(q) ||
          ed.contains(q) ||
          company.contains(q) ||
          endUser.contains(q);
    }).toList();
  }

  // ── Init: resolve user codes & role ───────────────────────────────────────

  Future<void> _init() async {
    await _loadCodes();
    await _loadFirstPage();
  }

  Future<void> _loadCodes() async {
    try {
      final res = await ApiService.getMe();
      if (res['status'] == 'success' && res['data'] is Map<String, dynamic>) {
        final d = res['data'] as Map<String, dynamic>;
        _role =
            (d['role'] ?? d['user_role'] ?? d['type'] ?? '')
                .toString()
                .toLowerCase()
                .trim();
        _euCode =
            d['eu_code']?.toString() ??
            d['euCode']?.toString() ??
            d['company']?.toString();
        _customerCode =
            d['customer_code']?.toString() ??
            d['com_eu_code']?.toString() ??
            d['customerCode']?.toString() ??
            d['company']?.toString();
      }
    } catch (_) {}

    if ((_euCode == null || _euCode!.isEmpty) &&
        (_customerCode == null || _customerCode!.isEmpty)) {
      final prefs = await SharedPreferences.getInstance();
      _euCode = prefs.getString('eu_code');
      _customerCode = prefs.getString('customer_code');
    }
  }

  // ── Parse ──────────────────────────────────────────────────────────────────

  ({int totalPages, int totalItems, List<Map<String, dynamic>> items})
  _parsePage(Map<String, dynamic> response) {
    final data = response['data'];
    List<Map<String, dynamic>> items =
        data is List
            ? data
                .whereType<Map>()
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                .toList()
            : [];

    int totalPages = 1;
    int totalItems = items.length;

    // Check raw.data.pagination
    final raw = response['raw'];
    if (raw is Map) {
      final wrapper = raw['data'];
      if (wrapper is Map) {
        final pagination = wrapper['pagination'];
        if (pagination is Map) {
          totalPages =
              int.tryParse(pagination['totalPages']?.toString() ?? '1') ?? 1;
          totalItems =
              int.tryParse(pagination['totalItems']?.toString() ?? '0') ??
              totalItems;
        }
      }
    }

    // Also check top-level pagination key
    if (response['pagination'] is Map) {
      final p = response['pagination'] as Map;
      totalPages =
          int.tryParse(p['totalPages']?.toString() ?? '1') ?? totalPages;
      totalItems =
          int.tryParse(p['totalItems']?.toString() ?? '0') ?? totalItems;
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
      final response = await _fetchPage(1);
      if (!mounted) return;

      if (response == null) {
        setState(() {
          _error = 'Failed to load subscriptions.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _allSubscriptions = response.items;
        _totalPages = response.totalPages;
        _totalItems = response.totalItems;
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

  // ── Next page (lazy load) ──────────────────────────────────────────────────

  Future<void> _loadNextPage() async {
    if (_fetchingMore || _currentPage >= _totalPages) return;
    setState(() => _fetchingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final result = await _fetchPage(nextPage);
      if (!mounted) return;

      if (result != null && result.items.isNotEmpty) {
        final existing = _allSubscriptions.map((s) => _sln(s)).toSet();
        final newItems =
            result.items.where((s) => !existing.contains(_sln(s))).toList();

        setState(() {
          _allSubscriptions = [..._allSubscriptions, ...newItems];
          _currentPage = nextPage;
          if (result.totalItems > 0) _totalItems = result.totalItems;
          if (result.totalPages > 0) _totalPages = result.totalPages;
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

  /// Fetches a single page using the correct endpoint based on role/codes.
  Future<_PageResult?> _fetchPage(int page) async {
    try {
      Map<String, dynamic>? response;

      final isAdminLike =
          _role == 'admin' ||
          _role == 'agent' ||
          _role == 'biller' ||
          _role == 'billing';

      if (isAdminLike) {
        response = await ApiService.getSubscriptionsPaginated(
          page: page,
          limit: _pageSize,
        );
      } else if (_euCode != null && _euCode!.isNotEmpty) {
        response = await ApiService.getSubscriptionsByEndUserId(_euCode!);
      } else if (_customerCode != null && _customerCode!.isNotEmpty) {
        response = await ApiService.getSubscriptionsByCustomerId(
          _customerCode!,
        );
      } else {
        response = await ApiService.getSubscriptionsPaginated(
          page: page,
          limit: _pageSize,
        );
      }

      if (response['status'] != 'success') return null;

      final parsed = _parsePage(response);
      return _PageResult(
        items: parsed.items,
        totalPages: parsed.totalPages,
        totalItems: parsed.totalItems,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Formatters ─────────────────────────────────────────────────────────────

  String _formatDate(String raw) {
    if (raw.isEmpty || raw == '—' || raw == '0000-00-00') return '—';
    try {
      final clean =
          raw.contains('T') ? raw.split('T').first : raw.split(' ').first;
      final dt = DateTime.parse(clean);
      if (dt.year < 1900) return '—';
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day.toString().padLeft(2, '0')}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: _surfaceSubtle,
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text(
                  'Subscriptions',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                centerTitle: true,
                backgroundColor: _surface,
                elevation: 0,
                iconTheme: const IconThemeData(color: _ink),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: _border),
                ),
              )
              : null,
      body: RefreshIndicator(
        onRefresh: _loadFirstPage,
        color: _primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Search bar ───────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _SearchBar(controller: _searchController),
              ),
            ),

            // ── Section header ───────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Text(
                      'SUBSCRIPTIONS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _inkTertiary,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_totalItems > 0 ? _totalItems : _allSubscriptions.length} results',
                      style: const TextStyle(
                        fontSize: 10,
                        color: _inkTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── List ─────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              sliver:
                  _loading
                      ? SliverList(
                        delegate: SliverChildListDelegate([
                          const _SkeletonTile(),
                          const SizedBox(height: 10),
                          const _SkeletonTile(),
                          const SizedBox(height: 10),
                          const _SkeletonTile(),
                        ]),
                      )
                      : _error != null && _allSubscriptions.isEmpty
                      ? SliverToBoxAdapter(child: _buildError())
                      : filtered.isEmpty
                      ? SliverToBoxAdapter(
                        child: _EmptyState(
                          icon: Icons.subscriptions_outlined,
                          message:
                              _searchController.text.trim().isNotEmpty
                                  ? 'No results for "${_searchController.text.trim()}".'
                                  : 'No subscriptions found.',
                        ),
                      )
                      : SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          // Footer: loading spinner or end message
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
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
                          final isActive = _isActiveSub(sub);
                          final nick = _nickname(sub);
                          final sl = _sln(sub);
                          final rawEnd = _endDate(sub);
                          final endDateStr =
                              rawEnd.isEmpty ? '—' : _formatDate(rawEnd);
                          final companyName =
                              (sub['company_name'] ?? '').toString().trim();
                          final endUserName =
                              (sub['end_user_name'] ?? '').toString().trim();
                          final searchQuery =
                              _searchController.text.trim().toLowerCase();

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _SubscriptionTile(
                              nickname: nick.isNotEmpty ? nick : sl,
                              serviceLineNumber: sl.isEmpty ? '—' : sl,
                              endDate: endDateStr,
                              isActive: isActive,
                              companyName: companyName,
                              endUserName: endUserName,
                              searchQuery: searchQuery,
                              onTap:
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) =>
                                              CustomerSubscriptionDetailsPage(
                                                serviceLineNumber: sl,
                                                title:
                                                    nick.isNotEmpty
                                                        ? nick
                                                        : (sl.isNotEmpty
                                                            ? sl
                                                            : 'Subscription'),
                                              ),
                                    ),
                                  ),
                            ),
                          );
                        }, childCount: filtered.length + 1),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats banner ───────────────────────────────────────────────────────────

  Widget _buildStatsBanner() {
    final total = _totalItems > 0 ? _totalItems : _allSubscriptions.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
              Icons.wifi_tethering_rounded,
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
                '$total',
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

  Widget _buildError() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded, color: _primary, size: 28),
        const SizedBox(height: 10),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: _inkSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
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
  );
}

// ── Page result helper ─────────────────────────────────────────────────────────

class _PageResult {
  final List<Map<String, dynamic>> items;
  final int totalPages;
  final int totalItems;
  const _PageResult({
    required this.items,
    required this.totalPages,
    required this.totalItems,
  });
}

// ── Subscription Tile ──────────────────────────────────────────────────────────

class _SubscriptionTile extends StatelessWidget {
  final String nickname;
  final String serviceLineNumber;
  final String endDate;
  final bool isActive;
  final String companyName;
  final String endUserName;
  final String searchQuery;
  final VoidCallback? onTap;

  const _SubscriptionTile({
    required this.nickname,
    required this.serviceLineNumber,
    required this.endDate,
    required this.isActive,
    this.companyName = '',
    this.endUserName = '',
    this.searchQuery = '',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _activeGreen : _primary;
    final statusLabel = isActive ? 'ACTIVE' : 'INACTIVE';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              // Icon box
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(
                    color.red,
                    color.green,
                    color.blue,
                    0.08,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isActive
                      ? Icons.wifi_tethering_rounded
                      : Icons.wifi_tethering_off_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Text column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HighlightText(
                      text: nickname,
                      query: searchQuery,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    _HighlightText(
                      text: serviceLineNumber,
                      query: searchQuery,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _inkSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (endUserName.isNotEmpty || companyName.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      _HighlightText(
                        text:
                            endUserName.isNotEmpty ? endUserName : companyName,
                        query: searchQuery,
                        style: const TextStyle(
                          fontSize: 10,
                          color: _inkTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        const Icon(
                          Icons.event_rounded,
                          size: 10,
                          color: _inkTertiary,
                        ),
                        const SizedBox(width: 3),
                        _HighlightText(
                          text: 'Expires $endDate',
                          query: searchQuery,
                          style: const TextStyle(
                            fontSize: 10,
                            color: _inkTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Status badge + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(
                        color.red,
                        color.green,
                        color.blue,
                        0.08,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Color.fromRGBO(
                          color.red,
                          color.green,
                          color.blue,
                          0.2,
                        ),
                      ),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: _inkTertiary,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Supporting Widgets ─────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          fontSize: 13,
          color: _ink,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search by name, line number, company…',
          hintStyle: const TextStyle(
            fontSize: 13,
            color: _inkTertiary,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: _inkTertiary,
            size: 18,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder:
                (_, value, __) =>
                    value.text.isNotEmpty
                        ? GestureDetector(
                          onTap: controller.clear,
                          child: const Icon(
                            Icons.close_rounded,
                            color: _inkTertiary,
                            size: 16,
                          ),
                        )
                        : const SizedBox.shrink(),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      color: _inkTertiary,
      letterSpacing: 1.4,
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        Icon(icon, color: _inkTertiary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: _inkSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;

  const _HighlightText({
    required this.text,
    required this.query,
    required this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }
    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;
    while (true) {
      final idx = lower.indexOf(query, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(
        TextSpan(
          text: text.substring(idx, idx + query.length),
          style: style.copyWith(
            color: _primary,
            backgroundColor: const Color.fromRGBO(235, 30, 35, 0.08),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      start = idx + query.length;
    }
    return RichText(
      text: TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) => Container(
    height: 80,
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        const SizedBox(width: 16),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _surfaceSubtle,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 11,
                width: 160,
                decoration: BoxDecoration(
                  color: _surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 7),
              Container(
                height: 9,
                width: 110,
                decoration: BoxDecoration(
                  color: _surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 8,
                width: 80,
                decoration: BoxDecoration(
                  color: _surfaceSubtle,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
      ],
    ),
  );
}
