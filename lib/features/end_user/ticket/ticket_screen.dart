import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/features/ticket/ticket_details_view.dart';
import 'package:starlink_app/shared/widgets/ticket_list_card.dart';
import 'package:starlink_app/core/utils/list_export.dart';
import 'package:starlink_app/shared/widgets/ticket_filter_bar.dart';
import 'package:starlink_app/features/end_user/ticket/ticket_modal.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// import 'package:provider/provider.dart'; // notifications disabled
// import 'package:starlink_app/providers/notification_provider.dart'; // notifications disabled

// ── Design tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFF133341);
const _success = Color(0xFF10B981);
const _danger = Color(0xFFE57373);
const _ink = Color(0xFF111111);
const _inkSecondary = Color(0xFF666666);
const _inkTertiary = Color(0xFF888888);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF8F8F8);
const _border = Color(0xFFD7D7D7);

// ── Extended detail-screen tokens (matches CustomerViewScreen) ────────────────

// ── Status tint pairs (background, foreground) ────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// TICKET SCREEN  (end-user list view)
// ─────────────────────────────────────────────────────────────────────────────

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key, this.exportController});

  final ListExportController? exportController;

  @override
  _TicketScreenState createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _selectedFilter = 'All';
  String _typeFilter = '';
  String _requesterFilter = '';
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];
  bool _isLoading = true;
  String? _userId;
  List<Map<String, dynamic>> _subscriptions = [];

  // ── Lazy pagination ────────────────────────────────────────────────────────
  static const _pageSize = 10;
  int _visibleCount = _pageSize;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    widget.exportController?.loader = _ticketsForExport;
    _loadUserData();
    _loadCategoriesAndTickets();
    _searchController.addListener(_handleSearch);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Notifications disabled: the backend has no /v1/notifications route.
      // Provider.of<NotificationProvider>(context, listen: false).refresh();
    });
  }

  @override
  void dispose() {
    widget.exportController?.loader = null;
    _searchController.removeListener(_handleSearch);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 250) _loadMore();
  }

  void _loadMore() {
    if (_isLoadingMore) return;
    if (_visibleCount >= _filteredTickets.length) return;
    setState(() => _isLoadingMore = true);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _visibleCount = (_visibleCount + _pageSize).clamp(
          0,
          _filteredTickets.length,
        );
        _isLoadingMore = false;
      });
    });
  }

  List<Map<String, dynamic>> get _visibleTickets =>
      _filteredTickets.take(_visibleCount).toList();

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userId = prefs.getInt('user_id')?.toString());
  }

  /// Tickets passing the search box and every filter.
  List<Map<String, dynamic>> _computeFiltered() {
    final query = _searchController.text.toLowerCase();
    return _tickets.where((ticket) {
      bool matchesFilter = true;
      if (_selectedFilter != 'All') {
        final ticketStatus =
            (ticket['status']?.toString() ?? '').toUpperCase().trim();
        final filterStatus = _selectedFilter.toUpperCase().trim();
        matchesFilter =
            ticketStatus.replaceAll('_', ' ') ==
            filterStatus.replaceAll('_', ' ');
      }
      bool matchesQuery =
          query.isEmpty ||
          ticket.values.any(
            (v) => v != null && v.toString().toLowerCase().contains(query),
          );
      return matchesFilter &&
          matchesQuery &&
          ticketMatchesDropdowns(
            ticket,
            type: _typeFilter,
            requester: _requesterFilter,
          );
    }).toList();
  }

  void _handleSearch() {
    setState(() {
      _filteredTickets = _computeFiltered();
      _visibleCount = _pageSize.clamp(0, _filteredTickets.length);
    });
  }

  Future<void> _loadSubscriptionsAndTickets() async {
    try {
      final subs = await ApiService.getSubscriptions();
      _subscriptions = subs.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      _subscriptions = [];
    }
    await _loadTickets();
  }

  Future<void> _loadCategoriesAndTickets() async {
    await _loadSubscriptionsAndTickets();
  }

  Future<List<Map<String, dynamic>>> _ticketsForExport() async {
    if (_isLoading) throw Exception('Tickets are still loading.');
    return _filteredTickets;
  }

  Future<void> _loadTickets({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> allTickets = [];
      int page = 1;
      bool hasMore = true;
      while (hasMore) {
        final response = await ApiService.getTickets(page: page, limit: 50);
        if (response['status'] != 'success') {
          throw Exception(response['message'] ?? 'Failed to load tickets');
        }
        final List<dynamic> data =
            response['data'] is List ? response['data'] : [];
        if (data.isEmpty) {
          hasMore = false;
        } else {
          allTickets.addAll(
            data.map((e) => Map<String, dynamic>.from(e)).toList(),
          );
          page++;
        }
      }

      final token = await ApiService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('No access token available.');
      }

      List<dynamic> contacts = [];
      try {
        contacts = await ApiService.getContacts(bearerToken: token);
      } catch (_) {}

      final agentMap = Map.fromEntries(
        contacts.map(
          (c) => MapEntry(c['id'].toString(), c['name']?.toString() ?? ''),
        ),
      );

      final loaded =
          allTickets.map((ticket) {
            final rawDate = ticket['created_at']?.toString();
            final createdAt = _formatDate(rawDate);

            final contactId = ticket['contact']?.toString() ?? '';
            final rawStatus =
                (ticket['status'] ?? 'open').toString().toLowerCase().trim();
            String displayStatus;
            switch (rawStatus) {
              case 'open':
                displayStatus = 'OPEN';
                break;
              case 'in_progress':
              case 'in progress':
              case 'inprogress':
                displayStatus = 'IN PROGRESS';
                break;
              case 'resolved':
                displayStatus = 'RESOLVED';
                break;
              case 'closed':
              case 'close':
                displayStatus = 'CLOSED';
                break;
              default:
                displayStatus = rawStatus.toUpperCase();
            }

            return {
              'id': ticket['id'],
              'type': ticket['ticket_type'] ?? ticket['type'] ?? 'N/A',
              'contact': ticket['created_by'] ?? '',
              'subject': ticket['subject'] ?? '',
              'description': ticket['description'] ?? '',
              'attachments': ticket['attachments'] ?? [],
              'status': displayStatus,
              'created_at': createdAt,
              'created_at_raw': rawDate,
              'user_id': ticket['user_id'],
              'full_data': ticket,
            };
          }).toList();
      if (!mounted) return;
      setState(() {
        _tickets = loaded;
        _filteredTickets = _computeFiltered();
        _visibleCount = _pageSize.clamp(0, _filteredTickets.length);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tickets = [];
        _filteredTickets = [];
        _isLoading = false;
      });
      AppToast.error(context, 'Error loading tickets: $e');
    }
  }

  String _getNickname(
    List<Map<String, dynamic>> subscriptions,
    String? serviceLineNumber,
  ) {
    if (serviceLineNumber == null || serviceLineNumber.isEmpty) return '';
    try {
      final match = subscriptions.firstWhere(
        (s) => s['serviceLineNumber']?.toString() == serviceLineNumber,
        orElse: () => {},
      );
      return match['nickname']?.toString() ?? serviceLineNumber;
    } catch (_) {
      return serviceLineNumber;
    }
  }

  void _showNewTicketModal() async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => EndUserTicketModal(
            userId: int.parse(_userId ?? '0'),
            onConfirm: (ticket) {
              if (ticket['id'] != null && mounted) {
                setState(() {
                  final serviceLineNumber =
                      ticket['full_data']?['subscription']?.toString();
                  final subscriptionNickname = _getNickname(
                    _subscriptions,
                    serviceLineNumber,
                  );
                  final contactName =
                      ticket['Contact'] ??
                      ticket['full_data']?['contact_name'] ??
                      '';
                  _tickets.insert(0, {
                    'id': ticket['id'],
                    'type': ticket['Ticket Type'] ?? 'N/A',
                    'contact': contactName,
                    'contact_id': ticket['full_data']?['contact'],
                    'subscription': subscriptionNickname,
                    'description': ticket['Description'] ?? '',
                    'attachments': ticket['Attachments'] ?? [],
                    'status': ticket['Status'] ?? 'OPEN',
                    'created_at':
                        ticket['Created At'] ??
                        _formatDate(DateTime.now().toString()),
                    'user_id': ticket['full_data']?['user_id'],
                    'full_data': {
                      ...ticket['full_data'],
                      'status': ticket['Status'] ?? 'OPEN',
                      'attachments': ticket['full_data']?['attachments'] ?? [],
                      'contact_name': contactName,
                    },
                  });
                  _filteredTickets = _computeFiltered();
                  _visibleCount = _pageSize.clamp(0, _filteredTickets.length);
                });
              }
            },
            onCancel: () => Navigator.of(dialogContext).pop(),
          ),
    );

    if (result != null && mounted) {
      AppToast.success(context, 'Ticket created successfully');
      setState(() => _isLoading = true);
      await _loadTickets(forceRefresh: true);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      // Parse as UTC then add 8 hours for Manila Time (UTC+8)
      final utcDate = DateTime.parse(dateStr).toUtc();
      final manilaDate = utcDate.add(const Duration(hours: 8));

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

      int hour = manilaDate.hour;
      int h = hour % 12;
      if (h == 0) h = 12;
      final m = manilaDate.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';

      return '${months[manilaDate.month - 1]} ${manilaDate.day.toString().padLeft(2, '0')}, ${manilaDate.year}  $h:$m $period';
    } catch (_) {
      return dateStr;
    }
  }

  // ── Ticket card (matches CustomerTicketScreen rich card) ───────────────────

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final ticketId = ticket['id']?.toString() ?? '';
    return TicketListCard(
      id: ticket['id']?.toString() ?? '',
      subject: ticket['subject']?.toString() ?? '',
      status: ticket['status']?.toString() ?? 'OPEN',
      description: ticket['description']?.toString() ?? '',
      type: ticket['type']?.toString() ?? '',
      createdBy: ticket['contact']?.toString() ?? '',
      createdAt: ticket['created_at_raw']?.toString(),
      searchQuery: _searchController.text,
      onTap: () async {
        final updated = await Navigator.push<Map<String, dynamic>>(
          context,
          MaterialPageRoute(
            builder:
                (_) => EndUserTicketDetailsScreen(
                  ticketId: ticketId,
                  ticket: ticket,
                ),
          ),
        );
        if (updated != null && mounted) {
          setState(() {
            final idx = _tickets.indexWhere(
              (t) => t['id'].toString() == ticketId,
            );
            if (idx != -1) {
              _tickets[idx] = {..._tickets[idx], ...updated};
              _filteredTickets = _computeFiltered();
            }
          });
        }
      },
    );
  }

  // ── Bottom indicator ───────────────────────────────────────────────────────

  Widget _buildBottomIndicator() {
    final bool hasMore = _visibleCount < _filteredTickets.length;
    if (hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: _primary),
          ),
        ),
      );
    }
    if (_filteredTickets.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          'All ${_filteredTickets.length} ticket${_filteredTickets.length == 1 ? '' : 's'} loaded',
          style: const TextStyle(fontSize: 11, color: _inkTertiary),
        ),
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final query = _searchController.text.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.confirmation_number_outlined,
            color: _inkTertiary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              query.isNotEmpty
                  ? 'No results for "$query".'
                  : _typeFilter.isNotEmpty || _requesterFilter.isNotEmpty
                  ? 'No tickets match your filters.'
                  : _selectedFilter != 'All'
                  ? 'No $_selectedFilter tickets found.'
                  : 'No tickets yet. Tap + to create one.',
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceSubtle,
      body: RefreshIndicator(
        onRefresh: _loadTickets,
        color: _primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Search + notification ──────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(child: _SearchBar(controller: _searchController)),
                    const SizedBox(width: 10),
                    // NotificationBadge(
                    //   child: GestureDetector(
                    //     onTap:
                    //         () => Navigator.push(
                    //           context,
                    //           MaterialPageRoute(
                    //             builder: (_) => const NotificationsPage(),
                    //           ),
                    //         ),
                    //     child: Container(
                    //       width: 46,
                    //       height: 46,
                    //       decoration: BoxDecoration(
                    //         color: _surface,
                    //         borderRadius: BorderRadius.circular(12),
                    //         border: Border.all(color: _border),
                    //         boxShadow: [
                    //           BoxShadow(
                    //             color: Colors.black.withOpacity(0.03),
                    //             blurRadius: 6,
                    //             offset: const Offset(0, 2),
                    //           ),
                    //         ],
                    //       ),
                    //       child: const Icon(
                    //         Icons.notifications_outlined,
                    //         color: _primary,
                    //         size: 20,
                    //       ),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),

            // ── Filters ───────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.only(top: 12),
              sliver: SliverToBoxAdapter(
                child: TicketFilterBar(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  tickets: _tickets,
                  status: _selectedFilter,
                  type: _typeFilter,
                  requester: _requesterFilter,
                  onStatus: (v) {
                    setState(() => _selectedFilter = v);
                    _handleSearch();
                  },
                  onType: (v) {
                    setState(() => _typeFilter = v);
                    _handleSearch();
                  },
                  onRequester: (v) {
                    setState(() => _requesterFilter = v);
                    _handleSearch();
                  },
                ),
              ),
            ),

            // ── Section header ─────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Text(
                      'ALL TICKETS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _inkTertiary,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedFilter != 'All' ||
                        _typeFilter.isNotEmpty ||
                        _requesterFilter.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedFilter = 'All';
                            _typeFilter = '';
                            _requesterFilter = '';
                          });
                          _handleSearch();
                        },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 28),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Clear filters'),
                      ),
                    if (!_isLoading)
                      Text(
                        '${_filteredTickets.length} result${_filteredTickets.length == 1 ? '' : 's'}',
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

            // ── List ───────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver:
                  _isLoading
                      ? SliverList(
                        delegate: SliverChildListDelegate([
                          const _SkeletonCard(),
                          const SizedBox(height: 10),
                          const _SkeletonCard(),
                          const SizedBox(height: 10),
                          const _SkeletonCard(),
                        ]),
                      )
                      : _filteredTickets.isEmpty
                      ? SliverToBoxAdapter(child: _buildEmptyState())
                      : SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          if (index == _visibleTickets.length) {
                            return _buildBottomIndicator();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildTicketCard(_visibleTickets[index]),
                          );
                        }, childCount: _visibleTickets.length + 1),
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewTicketModal,
        elevation: 6,
        tooltip: 'Create new ticket',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// END-USER TICKET DETAILS SCREEN
// Mirrors CustomerViewScreen exactly — calls /v1/tickets/:id, /v1/activities/:id,
// /v1/attachments/:id in parallel and uses the same card/timeline/attachment UI.
// ─────────────────────────────────────────────────────────────────────────────

class EndUserTicketDetailsScreen extends StatelessWidget {
  const EndUserTicketDetailsScreen({
    super.key,
    required this.ticketId,
    required this.ticket,
  });

  final String ticketId;
  final Map<String, dynamic> ticket;

  @override
  Widget build(BuildContext context) => TicketDetailsView(
    ticketId: ticketId,
    subject: ticket['subject']?.toString(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Search Bar widget (matches CustomerTicketScreen._SearchBar)
// ─────────────────────────────────────────────────────────────────────────────

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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          fontSize: 13,
          color: _ink,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Search by type, contact, description…',
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

// ─────────────────────────────────────────────────────────────────────────────
// Highlight Text (matches CustomerTicketScreen._HighlightText)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Small shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 12,
                      width: 140,
                      decoration: BoxDecoration(
                        color: _surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 20,
                      width: 60,
                      decoration: BoxDecoration(
                        color: _surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  height: 9,
                  width: 80,
                  decoration: BoxDecoration(
                    color: _surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: _border),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 9,
                            width: 50,
                            decoration: BoxDecoration(
                              color: _surfaceSubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 11,
                            width: 90,
                            decoration: BoxDecoration(
                              color: _surfaceSubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 9,
                            width: 60,
                            decoration: BoxDecoration(
                              color: _surfaceSubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 11,
                            width: 80,
                            decoration: BoxDecoration(
                              color: _surfaceSubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 9,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _surfaceSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  height: 9,
                  width: 200,
                  decoration: BoxDecoration(
                    color: _surfaceSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
