import 'package:flutter/material.dart';
import 'package:starlink_app/shared/widgets/ticket_list_card.dart';
import 'package:starlink_app/core/utils/list_export.dart';
import 'package:starlink_app/core/utils/ticket_export.dart';
import 'dart:async';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';
import 'package:starlink_app/features/admin/sections/ticket/admin_ticket_details_page.dart';
import 'package:starlink_app/features/admin/sections/ticket/admin_create_ticket_page.dart';

class AdminTicketsPage extends StatefulWidget {
  const AdminTicketsPage({super.key, this.exportController});

  final ListExportController? exportController;

  @override
  State<AdminTicketsPage> createState() => _AdminTicketsPageState();
}

class _AdminTicketsPageState extends State<AdminTicketsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _allTickets = [];

  bool _loading = false;
  bool _fetchingMore = false;
  String? _error;
  String? _role;

  int _totalItems = 0;
  int _totalPages = 1;
  int _currentPage = 1;
  int _pageSize = 10;

  // Filters, applied by the server like the web portal ('' = any).
  String _status = '';
  String _type = '';
  String _creator = '';
  String _requester = '';
  List<SelectOption<String>> _typeOptions = const [];
  List<SelectOption<String>> _creatorOptions = const [];
  List<SelectOption<String>> _requesterOptions = const [];

  // Only the latest request may update the list (filters can change quickly).
  int _requestSeq = 0;

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const _primary = Color(0xFF133341);
  static const _ink = Color(0xFF111111);
  static const _inkSecondary = Color(0xFF666666);
  static const _inkTertiary = Color(0xFF888888);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceSubtle = Color(0xFFF8F8F8);
  static const _border = Color(0xFFD7D7D7);

  @override
  void initState() {
    super.initState();
    widget.exportController?.loader =
        () => fetchAllTickets(fetchPage: _fetchTickets);
    _loadFirstPage();
    _loadFilterOptions();
    _loadUserRole();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadUserRole() async {
    final me = await ApiService.getMe();
    if (me['status'] == 'success') {
      final data = me['data'] is Map ? (me['data'] as Map) : {};
      final r =
          (data['role'] ?? data['user_role'] ?? data['type'] ?? '')
              .toString()
              .toLowerCase();
      if (mounted) setState(() => _role = r);
    }
  }

  @override
  void dispose() {
    widget.exportController?.loader = null;
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // ── Scroll ─────────────────────────────────────────────────────────────────

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_fetchingMore &&
        _currentPage < _totalPages) {
      _loadNextPage();
    }
  }

  // ── Filtering ──────────────────────────────────────────────────────────────

  bool get _hasFilters =>
      _status.isNotEmpty ||
      _type.isNotEmpty ||
      _creator.isNotEmpty ||
      _requester.isNotEmpty ||
      _searchController.text.trim().isNotEmpty;

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _status = _type = _creator = _requester = '';
    });
    _loadFirstPage();
  }

  /// Sets one filter and reloads from the first page.
  void _setFilter(VoidCallback change) {
    setState(change);
    _loadFirstPage();
  }

  /// One page with the current filters; also what Export reads.
  Future<Map<String, dynamic>> _fetchTickets(int page, int limit) =>
      ApiService.getTickets(
        page: page,
        limit: limit,
        status: _status,
        ticketType: _type,
        createdBy: _creator,
        requestedBy: _requester,
        search: _searchController.text.trim(),
      );

  Future<void> _loadFilterOptions() async {
    final res = await ApiService.getTicketFilterOptions();
    final data = res['data'];
    // Filters are optional: without them the list still works.
    if (!mounted || res['status'] != 'success' || data is! Map) return;
    List<SelectOption<String>> options(dynamic list) => [
      if (list is List)
        for (final o in list.whereType<Map>())
          if ('${o['value'] ?? ''}'.isNotEmpty)
            SelectOption(
              '${o['value']}',
              '${o['label'] ?? o['value']}',
              subtitle: o['email']?.toString(),
            ),
    ];
    setState(() {
      _typeOptions = options(data['ticket_types']);
      _creatorOptions = options(data['created_by']);
      _requesterOptions = options(data['assigned_by']);
    });
  }

  // ── Parse ──────────────────────────────────────────────────────────────────

  ({int totalPages, int totalItems, List<Map<String, dynamic>> items})
  _parsePage(Map<String, dynamic> response) {
    final List<Map<String, dynamic>> items = _parseList(response['data']);

    // Pagination lives inside response['raw']['data']['pagination']
    int totalPages = 1;
    int totalItems = 0;
    final raw = response['raw'];
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

    return (totalPages: totalPages, totalItems: totalItems, items: items);
  }

  List<Map<String, dynamic>> _parseList(dynamic data) {
    if (data is List) {
      return data
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadFirstPage() async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
      _allTickets = [];
      _totalItems = 0;
      _totalPages = 1;
      _currentPage = 1;
    });

    try {
      final response = await _fetchTickets(1, _pageSize);
      if (!mounted || seq != _requestSeq) return;

      if (response['status'] != 'success') {
        setState(() {
          _error = response['message']?.toString() ?? 'Failed to load tickets';
          _loading = false;
        });
        return;
      }

      final parsed = _parsePage(response);

      setState(() {
        _allTickets = parsed.items;
        _totalPages = parsed.totalPages;
        _totalItems = parsed.totalItems;
        _currentPage = 1;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_fetchingMore || _currentPage >= _totalPages) return;
    final seq = _requestSeq;
    setState(() => _fetchingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final response = await _fetchTickets(nextPage, _pageSize);
      if (!mounted || seq != _requestSeq) return;

      if (response['status'] == 'success') {
        final parsed = _parsePage(response);
        final existingIds = _allTickets.map((t) => t['id'].toString()).toSet();
        final newItems =
            parsed.items
                .where((t) => !existingIds.contains(t['id'].toString()))
                .toList();

        setState(() {
          _allTickets = [..._allTickets, ...newItems];
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

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _openTicket(Map<String, dynamic> t) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AdminTicketDetailsPage(
              ticketId: t['id'].toString(),
              subject: t['subject'] ?? '',
            ),
      ),
    ).then((changed) {
      if (changed != null && mounted) _loadFirstPage();
    });
  }

  Future<void> _openCreateTicket() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AdminCreateTicketPage()),
    );
    if (created == true && mounted) _loadFirstPage();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _allTickets;

    if (_role == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    return Scaffold(
      backgroundColor: _surface,
      floatingActionButton:
          _role == 'agent'
              ? null
              : FloatingActionButton.extended(
                onPressed: _openCreateTicket,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Create Ticket'),
              ),
      body: Column(
        children: [
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
                    const Duration(milliseconds: 350),
                    () {
                      if (mounted) _loadFirstPage();
                    },
                  );
                },
                style: const TextStyle(fontSize: 13, color: _ink),
                decoration: InputDecoration(
                  hintText: 'Search by subject, ID, requester…',
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
                              _searchDebounce?.cancel();
                              _searchController.clear();
                              _loadFirstPage();
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
                    vertical: 13,
                    horizontal: 16,
                  ),
                ),
              ),
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: FadingHScroll(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _filter(
                    width: 138,
                    value: _status,
                    title: 'Status',
                    anyLabel: 'All statuses',
                    options: const [
                      SelectOption('open', 'Open'),
                      SelectOption('in_progress', 'In Progress'),
                      SelectOption('resolved', 'Resolved'),
                      SelectOption('closed', 'Closed'),
                    ],
                    onChanged: (v) => _setFilter(() => _status = v),
                  ),
                  if (_typeOptions.isNotEmpty)
                    _filter(
                      width: 138,
                      value: _type,
                      title: 'Type',
                      anyLabel: 'All types',
                      options: _typeOptions,
                      onChanged: (v) => _setFilter(() => _type = v),
                    ),
                  if (_creatorOptions.isNotEmpty)
                    _filter(
                      width: 148,
                      value: _creator,
                      title: 'Creator',
                      anyLabel: 'Any creator',
                      options: _creatorOptions,
                      onChanged: (v) => _setFilter(() => _creator = v),
                    ),
                  if (_requesterOptions.isNotEmpty)
                    _filter(
                      width: 148,
                      value: _requester,
                      title: 'Requester',
                      anyLabel: 'Any requester',
                      options: _requesterOptions,
                      onChanged: (v) => _setFilter(() => _requester = v),
                    ),
                  SizedBox(
                    width: 132,
                    child: AppSelect<int>(
                      dense: true,
                      sheetTitle: 'Per page',
                      value: _pageSize,
                      options: const [
                        SelectOption(5, '5 per page'),
                        SelectOption(10, '10 per page'),
                        SelectOption(20, '20 per page'),
                        SelectOption(50, '50 per page'),
                      ],
                      onChanged: (v) => _setFilter(() => _pageSize = v),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // List header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Tickets',
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
                    _totalItems > 0 ? '$_totalItems' : '${_allTickets.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ),
                const Spacer(),
                if (_hasFilters)
                  TextButton(
                    onPressed: _clearFilters,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Clear filters'),
                  ),
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
                    : _error != null && _allTickets.isEmpty
                    ? _buildError()
                    : filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                      onRefresh: _loadFirstPage,
                      color: _primary,
                      strokeWidth: 2,
                      child: ListView.builder(
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
                                _allTickets.isNotEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                child: Center(
                                  child: Text(
                                    'All ${_totalItems > filtered.length ? _totalItems : filtered.length} tickets loaded',
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
                          final t = filtered[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: RepaintBoundary(
                              child: TicketListCard(
                                id: '${t['id'] ?? '-'}',
                                subject: (t['subject'] ?? '').toString(),
                                status: (t['status'] ?? '').toString(),
                                description:
                                    (t['description'] ?? '').toString(),
                                type: (t['ticket_type'] ?? '').toString(),
                                createdBy:
                                    (t['created_by'] ?? t['requester'] ?? '')
                                        .toString(),
                                createdAt: t['created_at']?.toString(),
                                searchQuery: _searchController.text,
                                onTap: () => _openTicket(t),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  // ── Stats banner ───────────────────────────────────────────────────────────

  Widget _filter({
    required double width,
    required String value,
    required String title,
    required String anyLabel,
    required List<SelectOption<String>> options,
    required ValueChanged<String> onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: SizedBox(
      width: width,
      child: AppSelect<String>(
        dense: true,
        sheetTitle: title,
        value: value,
        options: [SelectOption('', anyLabel), ...options],
        onChanged: onChanged,
      ),
    ),
  );

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
              color: Color(0xFFE90408),
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
              textStyle: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
              ),
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
            Icons.confirmation_num_outlined,
            color: _inkTertiary,
            size: 24,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _hasFilters ? 'No tickets match your filters' : 'No tickets found',
          style: const TextStyle(fontSize: 14, color: _inkSecondary),
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

  static const _border = Color(0xFFD7D7D7);
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
                              width: 200,
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
                                  width: 60,
                                  decoration: BoxDecoration(
                                    color: _border.withOpacity(opacity),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  height: 16,
                                  width: 80,
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
                              width: 180,
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

// ── Ticket card ────────────────────────────────────────────────────────────────
