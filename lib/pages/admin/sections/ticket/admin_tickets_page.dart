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
  static const int _pageSize = 50;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadTickets();
        _measureHeader();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadTickets() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _allTickets = [];
      _totalItems = 0;
      _totalPages = 1;
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
        _allTickets = page1Items;
        _totalPages = totalPages;
        _totalItems = totalItems;
        _loading = false;
      });

      if (totalPages > 1) _fetchRemainingPages(totalPages);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _fetchRemainingPages(int totalPages) async {
    if (!mounted) return;
    setState(() => _fetchingMore = true);
    try {
      for (int page = 2; page <= totalPages; page++) {
        if (!mounted) break;
        final response = await ApiService.getTickets(
          page: page,
          limit: _pageSize,
        );
        if (!mounted) break;
        if (response['status'] == 'success') {
          final items = _parseList(response['data']);
          if (mounted && items.isNotEmpty) {
            setState(() {
              final existingIds =
                  _allTickets.map((t) => t['id'].toString()).toSet();
              final newItems =
                  items
                      .where((t) => !existingIds.contains(t['id'].toString()))
                      .toList();
              _allTickets = [..._allTickets, ...newItems];
            });
          }
        }
      }
    } catch (_) {
      // silently ignore
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
    if (created == true && mounted) _loadTickets();
  }

  // ── Self-measuring header height ──────────────────────────────────────────

  final GlobalKey _headerKey = GlobalKey();
  double _headerHeight = 180.0; // safe initial estimate

  void _measureHeader() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _headerKey.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) return;
      final h = box.size.height;
      if (h > 0 && (h - _headerHeight).abs() > 1) {
        setState(() => _headerHeight = h);
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTickets;
    final total = _totalItems > 0 ? _totalItems : _allTickets.length;

    return Scaffold(
      backgroundColor: _surface,
      // FAB stays bottom-right (unchanged)
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
      body:
          _loading
              ? _buildLoader()
              : _error != null && _allTickets.isEmpty
              ? _buildError()
              : RefreshIndicator(
                onRefresh: _loadTickets,
                color: _primary,
                strokeWidth: 2,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ── Pinned header ──────────────────────────────
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyHeaderDelegate(
                        height: _headerHeight,
                        child: _buildStickyHeader(total, filtered.length),
                      ),
                    ),

                    // ── Ticket list ────────────────────────────────────
                    if (filtered.isEmpty)
                      SliverFillRemaining(child: _buildEmpty())
                    else ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: RepaintBoundary(
                                child: _TicketCard(
                                  ticket: filtered[index],
                                  onTap: () => _openTicket(filtered[index]),
                                  statusColor: _statusColor(
                                    (filtered[index]['status'] ?? '')
                                        .toString(),
                                  ),
                                  formattedDate: _formatDate(
                                    filtered[index]['created_at']?.toString(),
                                  ),
                                ),
                              ),
                            ),
                            childCount: filtered.length,
                          ),
                        ),
                      ),

                      // Bottom indicator
                      SliverToBoxAdapter(
                        child:
                            _fetchingMore
                                ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            color: _primary,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Loading more tickets…',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: _inkTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : const SizedBox(height: 100),
                      ),
                    ],
                  ],
                ),
              ),
    );
  }

  // ── Sticky header ──────────────────────────────────────────────────────────

  Widget _buildStickyHeader(int total, int filteredCount) {
    return ColoredBox(
      key: _headerKey,
      color: _surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Search bar ─────────────────────────────────────────────────
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

          // ── Tab bar ────────────────────────────────────────────────────
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
                _tab('All', _allTickets.length, _inkSecondary),
                _tab('Open', _openCount, _warning),
                _tab('In Progress', _inProgressCount, _inProgressColor),
                _tab('Resolved', _resolvedCount, _success),
                _tab('Closed', _closedCount, _inkTertiary),
              ],
            ),
          ),

          // ── List title row ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
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
                    '$filteredCount${_fetchingMore ? '+' : ''}',
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
                    '${_allTickets.length} / $_totalItems',
                    style: const TextStyle(fontSize: 11, color: _inkTertiary),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: _loadTickets,
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

          // Divider
          Container(height: 1, color: _border),
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

  // ── State widgets ──────────────────────────────────────────────────────────

  Widget _buildLoader() => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
        ),
        SizedBox(height: 14),
        Text(
          'Loading tickets…',
          style: TextStyle(fontSize: 13, color: _inkSecondary),
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
            onPressed: _loadTickets,
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

// ── Sticky header delegate ─────────────────────────────────────────────────────

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  const _StickyHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox(height: height, child: child);

  @override
  bool shouldRebuild(_StickyHeaderDelegate old) => old.height != height;
}

// ── Ticket card ────────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onTap;
  final Color statusColor;
  final String formattedDate;

  static const _ink = Color(0xFF000000);
  static const _inkSecondary = Color(0xFF6F6F6F);
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
              // Avatar
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

              // Body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject + status badge
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

                    // Ticket ID meta tag
                    Row(
                      children: [
                        _MetaTag(label: '#', value: _id),
                        if (_ticketType.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _MetaTag(label: 'Type', value: _ticketType),
                        ],
                      ],
                    ),

                    const SizedBox(height: 8),
                    Container(height: 1, color: _border),
                    const SizedBox(height: 8),

                    // Footer: requester + date + chevron
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
      '$label $value',
      style: const TextStyle(
        fontSize: 9,
        color: _inkTertiary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
