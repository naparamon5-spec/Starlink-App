import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'customer_ticket_modal.dart';
import 'customer_view.dart';
import 'dart:convert';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _inProgress = Color(0xFF0F62FE);
const _success = Color(0xFF24A148);
const _warning = Color(0xFFFF832B);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);

class CustomerTicketScreen extends StatefulWidget {
  final bool showAppBar;
  const CustomerTicketScreen({super.key, this.showAppBar = true});

  @override
  _CustomerTicketState createState() => _CustomerTicketState();
}

class _CustomerTicketState extends State<CustomerTicketScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _selectedFilter = 'All';

  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];

  // ── Lazy loading ─────────────────────────────────────────────────────────
  static const _pageSize = 10;
  int _visibleCount = _pageSize;
  bool _isLoadingMore = false;

  bool _isLoading = true;
  int? _userId;

  final List<String> _filterOptions = [
    'All',
    'Open',
    'In Progress',
    'Resolved',
    'Closed',
  ];
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
    _loadUserData();
    _searchController.addListener(_handleSearch);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading tickets: $e'),
          backgroundColor: _primary,
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Ticket created successfully'),
            ],
          ),
          backgroundColor: _success,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
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
                  'My Tickets',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                centerTitle: true,
                elevation: 0,
                backgroundColor: _surface,
                foregroundColor: _ink,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Container(height: 1, color: _border),
                ),
              )
              : null,
      body: RefreshIndicator(
        onRefresh: _loadTickets,
        color: _primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Search Bar ─────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _SearchBar(controller: _searchController),
              ),
            ),

            // ── Filter chips ───────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filterOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final option = _filterOptions[i];
                      final isSelected = _selectedFilter == option;
                      final dotColor =
                          option == 'All' ? _primary : _statusColor(option);
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedFilter = option);
                          _applyFilter();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? dotColor.withOpacity(0.1)
                                    : _surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? dotColor : _border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (option != 'All') ...[
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                option,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                  color: isSelected ? dotColor : _inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // ── Section header + count ─────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const _SectionHeader(title: 'MY TICKETS'),
                    const Spacer(),
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
        backgroundColor: _primary,
        tooltip: 'Create new ticket',
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ── Bottom indicator ──────────────────────────────────────────────────────

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
    final String ticketType = ticket['Ticket Type']?.toString() ?? 'N/A';
    final String createdAt = ticket['Created At']?.toString() ?? 'N/A';
    final String description =
        ticket['Description']?.toString() ?? 'No description';
    final String contact = ticket['Contact']?.toString() ?? 'N/A';
    final String subscription = ticket['Subscription']?.toString() ?? 'N/A';
    final String status = ticket['Status']?.toString() ?? 'OPEN';
    final Color statusColor = _statusColorFromLabel(status);
    final String query = _searchController.text.trim().toLowerCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
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
                  (_tickets[idx]['full_data']
                          as Map<String, dynamic>)['status'] =
                      resultStatus;
                }
                _applyFilter();
              });
            }
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_statusIcon(status), color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),

              // Body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _HighlightText(
                            text: ticketType,
                            query: query,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(status: status, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: 2),
                    _HighlightText(
                      text: createdAt,
                      query: query,
                      style: const TextStyle(fontSize: 11, color: _inkTertiary),
                    ),
                    const SizedBox(height: 10),
                    Container(height: 1, color: _border),
                    const SizedBox(height: 10),

                    // Meta
                    Row(
                      children: [
                        Expanded(
                          child: _MetaField(
                            label: 'Contact',
                            value: contact,
                            query: query,
                          ),
                        ),
                        Expanded(
                          child: _MetaField(
                            label: 'Subscription',
                            value: subscription,
                            query: query,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Description
                    _HighlightText(
                      text: description,
                      query: query,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _inkSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: const [
                        Text(
                          'View details',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: _primary,
                          size: 14,
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _statusColor(String filterLabel) {
    switch (filterLabel.toUpperCase()) {
      case 'OPEN':
        return _warning;
      case 'IN PROGRESS':
        return _inProgress;
      case 'RESOLVED':
        return _success;
      case 'CLOSED':
        return _inkTertiary;
      default:
        return _inkTertiary;
    }
  }

  Color _statusColorFromLabel(String status) => _statusColor(status);

  IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return Icons.error_outline;
      case 'IN PROGRESS':
        return Icons.sync;
      case 'RESOLVED':
        return Icons.check_circle_outline;
      case 'CLOSED':
        return Icons.lock_outline;
      default:
        return Icons.help_outline;
    }
  }

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
      'Contact': raw['requester'] ?? raw['created_by'] ?? 'N/A',
      'Subscription': raw['subscription'] ?? raw['subject'] ?? 'N/A',
      'Description': raw['description'] ?? 'No description',
      'Created At': _formatDate(raw['created_at']),
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
      final date = DateTime.parse(dateStr).toLocal();
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
      return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  // ── SharedPreferences helpers ─────────────────────────────────────────────

  Future<void> _saveInProgressTicketIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('in_progress_ticket_ids', ids);
  }

  Future<List<String>> _getInProgressTicketIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('in_progress_ticket_ids') ?? [];
  }

  Future<void> _setTicketInProgress(String ticketId) async {
    final ids = await _getInProgressTicketIds();
    if (!ids.contains(ticketId)) {
      ids.add(ticketId);
      await _saveInProgressTicketIds(ids);
    }
  }

  Future<void> _removeTicketInProgress(String ticketId) async {
    final ids = await _getInProgressTicketIds();
    ids.remove(ticketId);
    await _saveInProgressTicketIds(ids);
  }

  Future<void> _saveInProgressTicketData(Map<String, dynamic> ticket) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('in_progress_tickets_data') ?? [];
    rawList.removeWhere((item) {
      final data = jsonDecode(item);
      return data['id'].toString() == ticket['id'].toString();
    });
    rawList.add(jsonEncode(ticket));
    await prefs.setStringList('in_progress_tickets_data', rawList);
  }

  Future<void> _removeInProgressTicketData(String ticketId) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('in_progress_tickets_data') ?? [];
    rawList.removeWhere((item) {
      final data = jsonDecode(item);
      return data['id'].toString() == ticketId;
    });
    await prefs.setStringList('in_progress_tickets_data', rawList);
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
            vertical: 12,
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
      if (idx > start) spans.add(TextSpan(text: text.substring(start, idx)));
      spans.add(
        TextSpan(
          text: text.substring(idx, idx + query.length),
          style: style.copyWith(
            color: _primary,
            backgroundColor: _primary.withOpacity(0.08),
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

// ── Status Chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Text(
      status.toUpperCase(),
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w800,
        fontSize: 9,
        letterSpacing: 0.5,
      ),
    ),
  );
}

// ── Meta Field ────────────────────────────────────────────────────────────────

class _MetaField extends StatelessWidget {
  final String label;
  final String value;
  final String query;
  const _MetaField({required this.label, required this.value, this.query = ''});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: _inkTertiary)),
      const SizedBox(height: 2),
      _HighlightText(
        text: value,
        query: query,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

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
