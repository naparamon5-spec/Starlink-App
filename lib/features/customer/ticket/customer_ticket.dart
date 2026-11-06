import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/shared/widgets/ticket_list_card.dart';
import 'package:starlink_app/core/utils/list_export.dart';
import 'package:starlink_app/shared/widgets/ticket_filter_bar.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/features/customer/ticket/customer_ticket_modal.dart';
import 'package:starlink_app/features/customer/ticket/customer_view.dart';
import 'dart:convert';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFF133341);
const _success = Color(0xFF10B981);
const _ink = Color(0xFF111111);
const _inkSecondary = Color(0xFF666666);
const _inkTertiary = Color(0xFF888888);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF8F8F8);
const _border = Color(0xFFD7D7D7);

class CustomerTicketScreen extends StatefulWidget {
  final bool showAppBar;
  final ListExportController? exportController;
  const CustomerTicketScreen({
    super.key,
    this.showAppBar = true,
    this.exportController,
  });

  @override
  _CustomerTicketState createState() => _CustomerTicketState();
}

class _CustomerTicketState extends State<CustomerTicketScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _selectedFilter = 'All';
  String _typeFilter = '';
  String _requesterFilter = '';

  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];

  // ── Lazy loading ──────────────────────────────────────────────────────────
  static const _pageSize = 10;
  int _visibleCount = _pageSize;
  bool _isLoadingMore = false;

  bool _isLoading = true;
  int? _userId;

  final List<String> _tableHeaders = [
    'Status',
    'Ticket Type',
    'Contact',
    'Subscription',
    'Description',
    'Created At',
    'Attachments',
  ];

  @override
  void initState() {
    super.initState();
    widget.exportController?.loader = _ticketsForExport;
    _loadUserData();
    _searchController.addListener(_handleSearch);
    _scrollController.addListener(_onScroll);
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

  // ── Fixed scroll listener: triggers when within 300px of the bottom ───────
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  // ── Load 10 more items, with a small artificial delay for UX ─────────────
  void _loadMore() {
    if (_isLoadingMore) return;
    if (_visibleCount >= _filteredTickets.length) return;

    setState(() => _isLoadingMore = true);

    Future.delayed(const Duration(milliseconds: 400), () {
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

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId != null) setState(() => _userId = userId);
      _loadTickets();
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _ticketsForExport() async {
    if (_isLoading) throw Exception('Tickets are still loading.');
    return _filteredTickets;
  }

  void _handleSearch() => _applyFilter();

  Future<List<Map<String, dynamic>>> _fetchAllTicketsForStatus(
    String status,
  ) async {
    final List<Map<String, dynamic>> all = [];
    int page = 1;
    const int limit = 50;
    while (true) {
      final response = await ApiService.getTickets(
        page: page,
        limit: limit,
        status: status,
      );
      if (response['status'] != 'success') break;
      final items = response['data'];
      if (items is! List || items.isEmpty) break;
      all.addAll(
        List<Map<String, dynamic>>.from(
          items.map((t) => Map<String, dynamic>.from(t as Map)),
        ),
      );
      final pagination = response['pagination'];
      if (pagination != null) {
        final totalPages =
            int.tryParse(pagination['totalPages'].toString()) ?? 1;
        if (page >= totalPages) break;
      } else {
        break;
      }
      page++;
    }
    return all;
  }

  Future<void> _loadTickets() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _fetchAllTicketsForStatus('open'),
        _fetchAllTicketsForStatus('in_progress'),
        _fetchAllTicketsForStatus('resolved'),
        _fetchAllTicketsForStatus('closed'),
      ]);

      final rawTickets = [
        ...results[0],
        ...results[1],
        ...results[2],
        ...results[3],
      ];
      final seen = <String>{};
      final unique =
          rawTickets.where((t) {
            final key = t['id']?.toString() ?? '';
            return key.isNotEmpty && seen.add(key);
          }).toList();

      final List<Map<String, dynamic>> loadedTickets =
          unique.map(_mapTicket).toList();

      final inProgressIds = await _getInProgressTicketIds();
      for (var ticket in loadedTickets) {
        if (inProgressIds.contains(ticket['id'].toString())) {
          ticket['Status'] = 'IN PROGRESS';
          (ticket['full_data'] as Map<String, dynamic>)['status'] =
              'IN PROGRESS';
        }
      }

      final inProgressTickets = await _getInProgressTicketsData();
      for (var ticket in inProgressTickets) {
        if (!loadedTickets.any(
          (t) => t['id'].toString() == ticket['id'].toString(),
        )) {
          String displayStatus =
              ticket['status']?.toString().toUpperCase() ?? 'IN PROGRESS';
          if (displayStatus == 'IN_PROGRESS') displayStatus = 'IN PROGRESS';
          loadedTickets.add({
            'id': ticket['id'],
            'Status': displayStatus,
            'Ticket Type': ticket['type'] ?? 'N/A',
            'Contact': ticket['contact_name'] ?? 'N/A',
            'Subscription': ticket['subscription'] ?? 'N/A',
            'Description': ticket['description'] ?? 'No description',
            'Created At': ticket['created_at'] ?? 'N/A',
            'Attachments': ticket['attachments'] ?? 'No attachments',
            'full_data': ticket['full_data'] ?? ticket,
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _tickets = loadedTickets;
        _isLoading = false;
        _applyFilter();
      });
    } catch (e) {
      debugPrint('Error loading tickets: $e');
      if (!mounted) return;
      setState(() {
        _tickets = [];
        _filteredTickets = [];
        _isLoading = false;
      });
      AppToast.error(context, 'Error loading tickets: $e');
    }
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    final filtered =
        _tickets.where((ticket) {
          final status = ticket['Status']?.toString().toUpperCase() ?? '';
          if (_selectedFilter != 'All') {
            if (status != _selectedFilter.toUpperCase()) return false;
          }
          if (!ticketMatchesDropdowns(
            ticket,
            type: _typeFilter,
            requester: _requesterFilter,
          )) {
            return false;
          }
          if (query.isNotEmpty) {
            return _tableHeaders.any((header) {
              final value = ticket[header]?.toString().toLowerCase() ?? '';
              return value.contains(query);
            });
          }
          return true;
        }).toList();

    setState(() {
      _filteredTickets = filtered;
      // Reset visible count to first page whenever filter changes
      _visibleCount = _pageSize.clamp(0, filtered.length);
    });
  }

  // ── New ticket modal ──────────────────────────────────────────────────────

  void _showNewTicketModal() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => CustomerTicketModal(
            userId: _userId ?? 0,
            onConfirm: (ticket) {
              if (ticket['id'] != null && mounted) {
                setState(() {
                  _tickets.insert(0, {
                    'id': ticket['id'],
                    'Status': ticket['Status'] ?? 'OPEN',
                    'Ticket Type': ticket['Ticket Type'] ?? 'N/A',
                    'Contact': ticket['Contact'] ?? 'N/A',
                    'Subscription': ticket['Subscription'] ?? 'N/A',
                    'Description': ticket['Description'] ?? 'No description',
                    'Created At':
                        ticket['Created At'] ??
                        _formatDate(DateTime.now().toString()),
                    'Attachments': ticket['Attachments'] ?? 'No attachments',
                    'full_data': {
                      'id': ticket['id'],
                      'type': ticket['Ticket Type'] ?? 'N/A',
                      'ticket_type': ticket['Ticket Type'] ?? 'N/A',
                      'contact': ticket['full_data']?['contact'],
                      'contact_name': ticket['Contact'] ?? 'N/A',
                      'subscription': ticket['Subscription'] ?? 'N/A',
                      'description': ticket['Description'] ?? 'No description',
                      'attachments': ticket['full_data']?['attachments'] ?? [],
                      'status': ticket['Status'] ?? 'OPEN',
                      'created_at':
                          ticket['Created At'] ??
                          _formatDate(DateTime.now().toString()),
                      'user_id': ticket['full_data']?['user_id'],
                    },
                  });
                  _applyFilter();
                });
              }
            },
            onCancel: () => Navigator.of(dialogContext).pop(),
          ),
    );

    if (result != null && mounted) {
      AppToast.success(context, 'Ticket created successfully');
      _loadTickets();
    }
  }

  void refreshTickets() => _loadTickets();

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceSubtle,
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text(
                  'Tickets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                centerTitle: true,
              )
              : null,
      body: RefreshIndicator(
        onRefresh: _loadTickets,
        color: _primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Search Bar ────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _SearchBar(controller: _searchController),
              ),
            ),

            // ── Filters ───────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.only(top: 12),
              sliver: SliverToBoxAdapter(
                child: TicketFilterBar(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  tickets: _tickets,
                  status: _selectedFilter,
                  type: _typeFilter,
                  requester: _requesterFilter,
                  onStatus: (v) {
                    setState(() => _selectedFilter = v);
                    _applyFilter();
                  },
                  onType: (v) {
                    setState(() => _typeFilter = v);
                    _applyFilter();
                  },
                  onRequester: (v) {
                    setState(() => _requesterFilter = v);
                    _applyFilter();
                  },
                ),
              ),
            ),

            // ── Section header + count ────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const _SectionHeader(title: 'ALL TICKETS'),
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
                          _applyFilter();
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

            // ── List ──────────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == _visibleTickets.length) {
                              return _buildBottomIndicator();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildTicketCard(_visibleTickets[index]),
                            );
                          },
                          // +1 for the bottom indicator slot
                          childCount: _visibleTickets.length + 1,
                        ),
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewTicketModal,
        tooltip: 'Create new ticket',
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ── Bottom indicator ──────────────────────────────────────────────────────

  Widget _buildBottomIndicator() {
    final bool hasMore = _visibleCount < _filteredTickets.length;
    if (_filteredTickets.isEmpty) return const SizedBox.shrink();

    if (hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading more… ($_visibleCount of ${_filteredTickets.length})',
              style: const TextStyle(fontSize: 11, color: _inkTertiary),
            ),
          ],
        ),
      );
    }

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

  // ── Empty state ───────────────────────────────────────────────────────────

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

  // ── Ticket card ───────────────────────────────────────────────────────────

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    return TicketListCard(
      id: '${ticket['id'] ?? ''}',
      subject:
          '${(ticket['full_data'] as Map?)?['subject'] ?? ticket['Subscription'] ?? ''}',
      status: ticket['Status']?.toString() ?? 'OPEN',
      description: ticket['Description']?.toString() ?? '',
      type: ticket['Ticket Type']?.toString() ?? '',
      createdBy: ticket['Contact']?.toString() ?? '',
      createdAt: ticket['created_at_raw']?.toString(),
      searchQuery: _searchController.text,
      onTap: () {
        final ticketData = {
          'id': ticket['id'],
          'type': ticket['Ticket Type'],
          'status': ticket['Status'],
          'subscription': ticket['Subscription'],
          'description': ticket['Description'],
          'created_at': ticket['Created At'],
          'attachments': ticket['Attachments'],
          'full_data': Map<String, dynamic>.from(ticket['full_data'] as Map),
        };
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerViewScreen(ticket: ticketData),
          ),
        ).then((result) {
          if (result != null && result is Map<String, dynamic>) {
            final resultStatus =
                result['status']?.toString().toUpperCase() ?? '';
            setState(() {
              final idx = _tickets.indexWhere(
                (t) => t['id'].toString() == result['id'].toString(),
              );
              if (idx != -1) {
                _tickets[idx]['Status'] = resultStatus;
                (_tickets[idx]['full_data'] as Map<String, dynamic>)['status'] =
                    resultStatus;
              }
              _applyFilter();
            });
          }
        });
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Map<String, dynamic> _mapTicket(Map<String, dynamic> raw) {
    final backendStatus = (raw['status'] ?? '').toString().toLowerCase().trim();
    String displayStatus;
    switch (backendStatus) {
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
        displayStatus = backendStatus.toUpperCase();
    }

    String attachmentsDisplay = 'No attachments';
    final rawAttachments = raw['attachments'];
    if (rawAttachments != null) {
      if (rawAttachments is List && rawAttachments.isNotEmpty) {
        final names =
            rawAttachments
                .where((a) => a != null)
                .map((a) => a is Map ? (a['name']?.toString() ?? '') : '')
                .where((n) => n.isNotEmpty)
                .toList();
        if (names.isNotEmpty) attachmentsDisplay = names.join(', ');
      } else if (rawAttachments is String && rawAttachments.isNotEmpty) {
        attachmentsDisplay = rawAttachments;
      }
    }

    final ticketType =
        raw['ticket_type'] ??
        _typeFromSubject(raw['subject']?.toString()) ??
        'N/A';

    return {
      'id': raw['id'],
      'Status': displayStatus,
      'Ticket Type': ticketType,
      'Contact': raw['created_by'] ?? raw['requester'] ?? 'N/A',
      'Subscription': raw['subscription'] ?? raw['subject'] ?? 'N/A',
      'Description': raw['description'] ?? 'No description',
      'Created At': _formatDate(raw['created_at']),
      'created_at_raw': raw['created_at'],
      'Attachments': attachmentsDisplay,
      'full_data': {
        ...raw,
        'created_at': _formatDate(raw['created_at']),
        'attachments': rawAttachments ?? [],
        'status': displayStatus,
        'type': ticketType,
        'ticket_type': ticketType,
      },
    };
  }

  String? _typeFromSubject(String? subject) {
    if (subject == null) return null;
    final idx = subject.indexOf(' - ');
    if (idx == -1) return null;
    return subject.substring(idx + 3).trim();
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

      final h = manilaDate.hour % 12 == 0 ? 12 : manilaDate.hour % 12;
      final m = manilaDate.minute.toString().padLeft(2, '0');
      final period = manilaDate.hour >= 12 ? 'PM' : 'AM';

      return '${months[manilaDate.month - 1]} ${manilaDate.day.toString().padLeft(2, '0')}, ${manilaDate.year}  $h:$m $period';
    } catch (_) {
      return dateStr;
    }
  }

  // ── SharedPreferences helpers ─────────────────────────────────────────────

  Future<List<String>> _getInProgressTicketIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('in_progress_ticket_ids') ?? [];
  }

  Future<List<Map<String, dynamic>>> _getInProgressTicketsData() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('in_progress_tickets_data') ?? [];
    return rawList
        .map((item) => Map<String, dynamic>.from(jsonDecode(item)))
        .toList();
  }
}

// ── Search Bar ────────────────────────────────────────────────────────────────

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

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: _inkTertiary,
      letterSpacing: 1.1,
    ),
  );
}

// ── Highlight Text ────────────────────────────────────────────────────────────

// ── Status Chip ───────────────────────────────────────────────────────────────

// ── Meta Field ────────────────────────────────────────────────────────────────

// ── Skeleton Card ─────────────────────────────────────────────────────────────

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
                      width: 110,
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
