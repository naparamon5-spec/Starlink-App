import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../services/api_service.dart';
import 'admin_ticket_details_page.dart';
import 'admin_create_ticket_page.dart';

class AdminTicketsPage extends StatefulWidget {
  const AdminTicketsPage({super.key});

  @override
  State<AdminTicketsPage> createState() => _AdminTicketsPageState();
}

class _AdminTicketsPageState extends State<AdminTicketsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  List<Map<String, dynamic>> _allTickets = [];

  bool _loading = false;
  bool _fetchingMore = false;
  String? _error;

  int _totalItems = 0;
  int _totalPages = 1;
  int _currentPage = 1;
  static const int _pageSize = 10;

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const _primary = Color(0xFFEB1E23);
  static const _inProgressColor = Color(0xFF0F62FE);
  static const _success = Color(0xFF24A148);
  static const _warning = Color(0xFFFF832B);
  static const _ink = Color(0xFF000000);
  static const _inkSecondary = Color(0xFF6F6F6F);
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadFirstPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
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

  List<Map<String, dynamic>> get _filteredTickets {
    final search = _searchController.text.toLowerCase().trim();
    return _allTickets.where((t) {
      final status = (t['status'] ?? '').toString().toLowerCase();
      bool tabMatch;
      switch (_tabController.index) {
        case 0:
          tabMatch = true;
          break;
        case 1:
          tabMatch = status.contains('open');
          break;
        case 2:
          tabMatch = status.contains('progress');
          break;
        case 3:
          tabMatch = status.contains('resolved');
          break;
        case 4:
          tabMatch = status.contains('closed') && !status.contains('resolved');
          break;
        default:
          tabMatch = true;
      }
      if (!tabMatch) return false;
      if (search.isNotEmpty) {
        final subject = (t['subject'] ?? '').toString().toLowerCase();
        final id = (t['id'] ?? '').toString();
        final createdBy = (t['created_by'] ?? '').toString().toLowerCase();
        final requester = (t['requester'] ?? '').toString().toLowerCase();
        final ticketType = (t['ticket_type'] ?? '').toString().toLowerCase();
        return subject.contains(search) ||
            id.contains(search) ||
            createdBy.contains(search) ||
            requester.contains(search) ||
            ticketType.contains(search);
      }
      return true;
    }).toList();
  }

  int get _openCount =>
      _allTickets
          .where(
            (t) =>
                (t['status'] ?? '').toString().toLowerCase().contains('open'),
          )
          .length;

  int get _inProgressCount =>
      _allTickets
          .where(
            (t) => (t['status'] ?? '').toString().toLowerCase().contains(
              'progress',
            ),
          )
          .length;

  int get _resolvedCount =>
      _allTickets
          .where(
            (t) => (t['status'] ?? '').toString().toLowerCase().contains(
              'resolved',
            ),
          )
          .length;

  int get _closedCount =>
      _allTickets
          .where(
            (t) =>
                (t['status'] ?? '').toString().toLowerCase().contains(
                  'closed',
                ) &&
                !(t['status'] ?? '').toString().toLowerCase().contains(
                  'resolved',
                ),
          )
          .length;

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
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _allTickets = [];
      _totalItems = 0;
      _totalPages = 1;
      _currentPage = 1;
    });

    try {
      final response = await ApiService.getTickets(page: 1, limit: _pageSize);
      if (!mounted) return;

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
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_fetchingMore || _currentPage >= _totalPages) return;
    setState(() => _fetchingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final response = await ApiService.getTickets(
        page: nextPage,
        limit: _pageSize,
      );
      if (!mounted) return;

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

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('open')) return _warning;
    if (s.contains('progress')) return _inProgressColor;
    if (s.contains('resolved')) return _success;
    if (s.contains('closed')) return _inkTertiary;
    return _inkTertiary;
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw);
      const m = [
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
      return '${m[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

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
    );
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
    final filtered = _filteredTickets;

    return Scaffold(
      backgroundColor: _surface,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateTicket,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Create Ticket',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      body: Column(
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
                    vertical: 13,
                    horizontal: 16,
                  ),
                ),
              ),
            ),
          ),

          // Tab bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: TabBar(
              controller: _tabController,
              labelColor: _primary,
              unselectedLabelColor: _inkTertiary,
              indicatorColor: _primary,
              indicatorSize: TabBarIndicatorSize.label,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              tabs: [
                _tab(
                  'All',
                  _totalItems > 0 ? _totalItems : _allTickets.length,
                  _inkSecondary,
                ),
                _tab('Open', _openCount, _warning),
                _tab('In Progress', _inProgressCount, _inProgressColor),
                _tab('Resolved', _resolvedCount, _success),
                _tab('Closed', _closedCount, _inkTertiary),
              ],
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
                                    'All $_totalItems tickets loaded',
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
                              child: _TicketCard(
                                ticket: t,
                                onTap: () => _openTicket(t),
                                statusColor: _statusColor(
                                  (t['status'] ?? '').toString(),
                                ),
                                formattedDate: _formatDate(
                                  t['created_at']?.toString(),
                                ),
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
              Icons.confirmation_num_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Tickets',
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

  Tab _tab(String label, int count, Color color) => Tab(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
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
            Icons.confirmation_num_outlined,
            color: _inkTertiary,
            size: 24,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'No tickets found',
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

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onTap;
  final Color statusColor;
  final String formattedDate;

  static const _ink = Color(0xFF000000);
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surface = Color(0xFFFFFFFF);
  static const _border = Color(0xFFE0E0E0);
  static const _primary = Color(0xFFEB1E23);

  const _TicketCard({
    required this.ticket,
    required this.onTap,
    required this.statusColor,
    required this.formattedDate,
  });

  String get _subject => (ticket['subject'] ?? 'No subject').toString();
  String get _id => (ticket['id'] ?? '-').toString();
  String get _status => (ticket['status'] ?? '').toString();
  String get _requester =>
      (ticket['requester'] ?? ticket['created_by'] ?? '—').toString();
  String get _ticketType => (ticket['ticket_type'] ?? '').toString();

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _subject.isNotEmpty ? _subject[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
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
                            _subject,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _ink,
                              letterSpacing: -0.2,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                            _status.toUpperCase().replaceAll('_', ' '),
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
                    Row(
                      children: [
                        _MetaTag(value: _id),
                        if (_ticketType.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _MetaTag(value: _ticketType),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(height: 1, color: _border),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 11,
                          color: _inkTertiary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _requester,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _inkTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 11,
                          color: _inkTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _inkTertiary,
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final String value;
  static const _inkTertiary = Color(0xFFA8A8A8);
  static const _surfaceSubtle = Color(0xFFF4F4F4);
  static const _border = Color(0xFFE0E0E0);

  const _MetaTag({required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: _surfaceSubtle,
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: _border),
    ),
    child: Text(
      '$value',
      style: const TextStyle(
        fontSize: 9,
        color: _inkTertiary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
