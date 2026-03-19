import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../components/notification_badge.dart';
import '../profile/notifications.dart';
import 'ticket_modal.dart';
import '../../../services/api_service.dart';
import '../../../utils/file_download/file_downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../../providers/notification_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _inProgress = Color(0xFF0F62FE);
const _success = Color(0xFF24A148);
const _warning = Color(0xFFFF832B);
const _danger = Color(0xFFE57373);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);

// ── Extended detail-screen tokens (matches CustomerViewScreen) ────────────────
const _detailBg = Color(0xFFF5F7FA);
const _detailBorder = Color(0xFFE8ECF0);
const _detailInkSecondary = Color(0xFF374151);
const _detailInkTertiary = Color(0xFF8A96A3);

// ── Status tint pairs (background, foreground) ────────────────────────────────
const _statusOpen = (Color(0xFFFFF3E0), Color(0xFFB45309));
const _statusInProgress = (Color(0xFFE8F0FE), Color(0xFF1A56DB));
const _statusResolved = (Color(0xFFE6F4EA), Color(0xFF1A7F37));
const _statusClosed = (Color(0xFFFDE8E8), Color(0xFF9A1417));

// ─────────────────────────────────────────────────────────────────────────────
// TICKET SCREEN  (end-user list view)
// ─────────────────────────────────────────────────────────────────────────────

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key});

  @override
  _TicketScreenState createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];
  bool _isLoading = true;
  String? _userId;
  List<Map<String, dynamic>> _subscriptions = [];

  // ── Lazy pagination ────────────────────────────────────────────────────────
  static const _pageSize = 10;
  int _visibleCount = _pageSize;
  bool _isLoadingMore = false;

  final List<String> _filterOptions = [
    'All',
    'Open',
    'In Progress',
    'Resolved',
    'Closed',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCategoriesAndTickets();
    _searchController.addListener(_handleSearch);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).refresh();
    });
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

  void _handleSearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTickets =
          _tickets.where((ticket) {
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
                  (v) =>
                      v != null && v.toString().toLowerCase().contains(query),
                );
            return matchesFilter && matchesQuery;
          }).toList();
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
            String createdAt = ticket['created_at'] ?? 'N/A';
            DateTime? parsed;
            try {
              if (createdAt != 'N/A') {
                parsed = DateTime.parse(createdAt);
                createdAt =
                    '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} '
                    '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
              }
            } catch (_) {}

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
              'contact': agentMap[contactId] ?? '',
              'contact_id': ticket['contact'],
              'subscription': ticket['subscription_id'] ?? '',
              'description': ticket['description'] ?? '',
              'attachments': ticket['attachments'] ?? [],
              'status': displayStatus,
              'created_at': createdAt,
              'created_at_raw': parsed,
              'user_id': ticket['user_id'],
              'full_data': ticket,
            };
          }).toList();

      if (!mounted) return;
      setState(() {
        _tickets = loaded;
        _filteredTickets = List.from(_tickets);
        _visibleCount = _pageSize.clamp(0, _tickets.length);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tickets = [];
        _filteredTickets = [];
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading tickets: $e'),
          backgroundColor: _danger,
        ),
      );
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
                  _filteredTickets = List.from(_tickets);
                  _visibleCount = _pageSize.clamp(0, _filteredTickets.length);
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
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      setState(() => _isLoading = true);
      await _loadTickets(forceRefresh: true);
    }
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  Color _filterDotColor(String filterLabel) {
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
        return _primary;
    }
  }

  Color _statusColorFromLabel(String status) => _filterDotColor(status);

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

  // ── Ticket card (matches CustomerTicketScreen rich card) ───────────────────

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final String ticketType = ticket['type']?.toString() ?? 'N/A';
    final String createdAt = ticket['created_at']?.toString() ?? 'N/A';
    final String description =
        ticket['description']?.toString() ?? 'No description';
    final String contact = ticket['contact']?.toString() ?? '—';
    final String subscription = ticket['subscription']?.toString() ?? '—';
    final String status = ticket['status']?.toString() ?? 'OPEN';
    final String ticketId = ticket['id']?.toString() ?? '';
    final Color statusColor = _statusColorFromLabel(status);
    final String query = _searchController.text.trim().toLowerCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
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
                _filteredTickets = List.from(_tickets);
              }
            });
          }
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
              // ── Status icon ──────────────────────────────────────────
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Title row ──────────────────────────────────────
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
                    if (ticketId.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      _HighlightText(
                        text: 'Ticket #$ticketId',
                        query: query,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _inkTertiary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    _HighlightText(
                      text: createdAt,
                      query: query,
                      style: const TextStyle(fontSize: 11, color: _inkTertiary),
                    ),
                    const SizedBox(height: 10),
                    Container(height: 1, color: _border),
                    const SizedBox(height: 10),
                    // ── Meta ───────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _MetaField(
                            label: 'Contact',
                            value: contact.isNotEmpty ? contact : '—',
                            query: query,
                          ),
                        ),
                        Expanded(
                          child: _MetaField(
                            label: 'Subscription',
                            value: subscription.isNotEmpty ? subscription : '—',
                            query: query,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
                    // ── Footer ─────────────────────────────────────────
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
                    NotificationBadge(
                      child: GestureDetector(
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsPage(),
                              ),
                            ),
                        child: Container(
                          width: 46,
                          height: 46,
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
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: _primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Filter chips ───────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                          option == 'All' ? _primary : _filterDotColor(option);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFilter = option;
                          });
                          _handleSearch();
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

            // ── Section header ─────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Text(
                      'MY TICKETS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _inkTertiary,
                        letterSpacing: 1.1,
                      ),
                    ),
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
        backgroundColor: _primary,
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

class EndUserTicketDetailsScreen extends StatefulWidget {
  final String ticketId;
  final Map<String, dynamic> ticket;

  const EndUserTicketDetailsScreen({
    super.key,
    required this.ticketId,
    required this.ticket,
  });

  @override
  State<EndUserTicketDetailsScreen> createState() =>
      _EndUserTicketDetailsScreenState();
}

class _EndUserTicketDetailsScreenState
    extends State<EndUserTicketDetailsScreen> {
  Map<String, dynamic>? _fetchedTicket;
  bool _isFetchingDetails = true;
  String? _fetchError;

  List<dynamic> _attachments = [];
  String? _attachmentsError;
  final Map<String, bool> _downloadingMap = {};

  @override
  void initState() {
    super.initState();
    _loadTicketDetails();
  }

  Future<void> _loadTicketDetails() async {
    if (!mounted) return;
    setState(() {
      _isFetchingDetails = true;
      _fetchError = null;
      _attachments = [];
      _attachmentsError = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getTicketById(widget.ticketId),
        ApiService.getTicketAttachments(widget.ticketId),
      ]);

      if (!mounted) return;

      // ── Ticket detail ─────────────────────────────────────────────────
      Map<String, dynamic>? ticket;
      String? ticketError;
      final ticketRes = results[0];
      if (ticketRes['status'] == 'success') {
        final d = ticketRes['data'];
        ticket = d is Map ? Map<String, dynamic>.from(d) : null;
      } else {
        ticketError =
            ticketRes['message']?.toString() ??
            'Failed to load ticket details.';
      }

      // ── Attachments ───────────────────────────────────────────────────
      List<dynamic> attachments = [];
      String? attErr;
      final attRes = results[1];
      if (attRes['status'] == 'success') {
        attachments = _extractList(attRes['data']);
        if (attachments.isEmpty) attachments = _extractList(attRes['raw']);
      } else {
        attErr = attRes['message']?.toString() ?? 'Failed to load attachments.';
      }

      setState(() {
        _fetchedTicket = ticket;
        _fetchError = ticketError;
        _attachments = attachments;
        _attachmentsError = attErr;
        _isFetchingDetails = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchError = 'Error loading ticket: $e';
        _isFetchingDetails = false;
      });
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<dynamic> _extractList(dynamic d) {
    if (d is List) return d;
    if (d is Map) {
      for (final key in [
        'data',
        'attachments',
        'items',
        'records',
        'results',
        'list',
      ]) {
        final v = d[key];
        if (v is List) return v;
      }
    }
    return [];
  }

  String get _currentStatus {
    final raw =
        _fetchedTicket?['status']?.toString() ??
        widget.ticket['full_data']?['status']?.toString() ??
        widget.ticket['status']?.toString() ??
        'OPEN';
    return _normalizeStatus(raw);
  }

  String _normalizeStatus(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'open':
      case 'opened':
        return 'OPEN';
      case 'in_progress':
      case 'in progress':
      case 'inprogress':
        return 'IN PROGRESS';
      case 'resolved':
      case 'done':
      case 'completed':
        return 'RESOLVED';
      case 'closed':
      case 'close':
        return 'CLOSED';
      default:
        return raw.toUpperCase();
    }
  }

  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'OPEN':
        return _warning;
      case 'IN PROGRESS':
        return _inProgress;
      case 'RESOLVED':
        return _success;
      case 'CLOSED':
        return const Color(0xFFA8A8A8);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
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

  String _statusDescription(String status) {
    switch (status) {
      case 'OPEN':
        return 'Your ticket is awaiting review by our support team.';
      case 'IN PROGRESS':
        return 'Our support team is currently working on your ticket.';
      case 'RESOLVED':
        return 'Your ticket has been resolved. Thank you for your patience.';
      case 'CLOSED':
        return 'This ticket has been closed.';
      default:
        return 'Status: $status';
    }
  }

  IconData _activityIcon(String? action) {
    final v = (action ?? '').toLowerCase();
    if (v.contains('creat')) return Icons.add_circle_outline_rounded;
    if (v.contains('updat') || v.contains('edit')) return Icons.edit_outlined;
    if (v.contains('resolv')) return Icons.check_circle_outline_rounded;
    if (v.contains('close') || v.contains('clos')) return Icons.cancel_outlined;
    if (v.contains('comment') || v.contains('note')) {
      return Icons.comment_outlined;
    }
    if (v.contains('assign')) return Icons.person_add_alt_outlined;
    if (v.contains('status') || v.contains('chang')) {
      return Icons.swap_horiz_rounded;
    }
    return Icons.history_toggle_off_outlined;
  }

  Color _activityColor(String? action) {
    final v = (action ?? '').toLowerCase();
    if (v.contains('creat')) return _success;
    if (v.contains('resolv')) return _success;
    if (v.contains('close')) return _warning;
    if (v.contains('comment') || v.contains('note')) {
      return const Color(0xFF6366F1);
    }
    if (v.contains('assign')) return _primary;
    if (v.contains('status') || v.contains('chang')) return _inProgress;
    return const Color(0xFF94A3B8);
  }

  String _timeAgo(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return _formatDate(raw);
    } catch (_) {
      return '';
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
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
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$m $period';
    } catch (_) {
      return raw;
    }
  }

  String _str(dynamic v, {String fallback = '—'}) {
    if (v == null || v.toString() == 'null' || v.toString().isEmpty) {
      return fallback;
    }
    return v.toString();
  }

  String _resolveValue(List<String?> candidates, {String fallback = 'N/A'}) {
    for (final v in candidates) {
      if (v != null && v.isNotEmpty && v != 'null') return v;
    }
    return fallback;
  }

  String _prettifyValue(String v) {
    switch (v.toLowerCase()) {
      case 'in_progress':
        return 'In Progress';
      case 'open':
        return 'Open';
      case 'closed':
        return 'Closed';
      case 'resolved':
        return 'Resolved';
      default:
        return v.isNotEmpty ? v[0].toUpperCase() + v.substring(1) : v;
    }
  }

  Color _extColor(String ext) {
    switch (ext) {
      case 'pdf':
        return _primary;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
        return _success;
      case 'doc':
      case 'docx':
        return _inProgress;
      case 'xls':
      case 'xlsx':
        return _success;
      case 'zip':
      case 'rar':
        return _warning;
      default:
        return const Color(0xFF6366F1);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? _primary : _success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _downloadAttachment(dynamic att) async {
    final attachmentId =
        att is Map
            ? _str(
              att['id'] ?? att['attachment_id'] ?? att['attachmentId'],
              fallback: '—',
            )
            : '—';
    if (attachmentId == '—' || attachmentId.isEmpty) {
      _showSnack('Cannot download: attachment ID is missing.', isError: true);
      return;
    }
    setState(() => _downloadingMap[attachmentId] = true);
    try {
      final result = await ApiService.downloadAttachment(attachmentId);
      if (!mounted) return;
      if (result['status'] != 'success') {
        _showSnack(
          result['message']?.toString() ?? 'Download failed.',
          isError: true,
        );
        return;
      }
      final filename =
          result['filename']?.toString().trim().isNotEmpty == true
              ? result['filename'].toString().trim()
              : _attFilename(att);
      final base64Str = result['base64']?.toString() ?? '';
      if (base64Str.isEmpty) {
        _showSnack('Download failed: empty file data.', isError: true);
        return;
      }
      Uint8List bytes;
      try {
        bytes = base64Decode(base64Str);
      } catch (e) {
        _showSnack('Download failed: invalid file data.', isError: true);
        return;
      }
      final mimeType =
          result['mimeType']?.toString() ?? 'application/octet-stream';
      final savedPath = await saveBytesAsFile(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
      );
      if (!mounted) return;
      _showSnack(
        savedPath != null && savedPath.isNotEmpty
            ? 'Saved to: $savedPath'
            : 'Downloaded: $filename',
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('Download error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _downloadingMap.remove(attachmentId));
    }
  }

  String _attFilename(dynamic att) {
    if (att is Map) {
      final f =
          att['name'] ?? att['filename'] ?? att['file_name'] ?? att['fileName'];
      if (f is String && f.trim().isNotEmpty) return f.trim();
    }
    return 'attachment';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final passedFull =
        (widget.ticket['full_data'] as Map<String, dynamic>?) ?? widget.ticket;
    final data = _fetchedTicket ?? passedFull;

    final status = _currentStatus;
    final statusColor = _statusColor(status);

    final String ticketId = _str(data['id'] ?? widget.ticket['id']);
    final String subject = _resolveValue([
      data['subject']?.toString(),
      passedFull['subject']?.toString(),
      widget.ticket['subscription']?.toString(),
    ], fallback: 'Ticket #$ticketId');

    final String ticketType = _resolveValue([
      data['ticket_type']?.toString(),
      data['type']?.toString(),
      widget.ticket['type']?.toString(),
    ]);
    final String contact = _resolveValue([
      data['contact_name']?.toString(),
      data['created_by']?.toString(),
      widget.ticket['contact']?.toString(),
    ]);
    final String createdAt = _resolveValue([
      data['created_at']?.toString(),
      passedFull['created_at']?.toString(),
      widget.ticket['created_at']?.toString(),
    ]);
    final String description = _resolveValue([
      data['description']?.toString(),
      passedFull['description']?.toString(),
      widget.ticket['description']?.toString(),
    ], fallback: 'No description provided.');

    final dynamic rawTimeline = data['timeline'];
    final List<dynamic> timeline = rawTimeline is List ? rawTimeline : [];

    return Scaffold(
      backgroundColor: _detailBg,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            Text(
              'Ticket #$ticketId',
              style: const TextStyle(fontSize: 11, color: _inkTertiary),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _primary, size: 20),
            onPressed: _isFetchingDetails ? null : _loadTicketDetails,
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _detailBorder),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTicketDetails,
        color: _primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // ── Ticket Info Card ────────────────────────────────────────
            _DetailCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Subject',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _detailInkTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subject,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _StatusBadge(label: status, color: statusColor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _HDivider(),
                  // Type chip
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _InfoChip(
                      icon: Icons.label_outline_rounded,
                      label: 'Type',
                      value: ticketType,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _HDivider(),
                  // Description
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 11,
                            color: _detailInkTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            description,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _detailInkSecondary,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _HDivider(),
                  // KV rows
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      children: [
                        _KVRow(label: 'Contact', value: contact),
                        const SizedBox(height: 8),
                        _KVRow(
                          label: 'Created At',
                          value: _formatDate(createdAt),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Attachments Card ────────────────────────────────────────
            _DetailCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _warning.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.attach_file_rounded,
                            color: _warning,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Attachments',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const Spacer(),
                        if (_isFetchingDetails)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primary,
                            ),
                          )
                        else if (_attachments.isNotEmpty)
                          _CountBadge(
                            count: _attachments.length,
                            color: _warning,
                          ),
                      ],
                    ),
                  ),
                  const _HDivider(),
                  if (_isFetchingDetails)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primary,
                        ),
                      ),
                    )
                  else if (_attachmentsError != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: _danger,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _attachmentsError!,
                              style: const TextStyle(
                                color: _inkSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => _attachmentsError = null);
                              _loadTicketDetails();
                            },
                            child: const Text(
                              'Retry',
                              style: TextStyle(color: _primary, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_attachments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: _inkTertiary,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'No attachments',
                            style: TextStyle(color: _inkTertiary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      itemCount: _attachments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final att = _attachments[i];
                        if (att is! Map) return const SizedBox.shrink();
                        final name = _str(
                          att['name'] ??
                              att['filename'] ??
                              att['file_name'] ??
                              att['original_name'],
                          fallback: 'Unknown file',
                        );
                        final ext =
                            name.contains('.')
                                ? name.split('.').last.toLowerCase()
                                : '';
                        final size = _str(
                          att['size'] ?? att['file_size'],
                          fallback: '',
                        );
                        final attId =
                            att['id']?.toString() ??
                            att['attachment_id']?.toString() ??
                            '';
                        final isDownloading =
                            attId.isNotEmpty && _downloadingMap[attId] == true;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _extColor(ext).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    ext.isNotEmpty
                                        ? ext.toUpperCase().substring(
                                          0,
                                          ext.length > 4 ? 4 : ext.length,
                                        )
                                        : 'FILE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: _extColor(ext),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: _ink,
                                      ),
                                    ),
                                    if (size.isNotEmpty)
                                      Text(
                                        size,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: _inkTertiary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              isDownloading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _inkTertiary,
                                    ),
                                  )
                                  : IconButton(
                                    icon: const Icon(
                                      Icons.download_outlined,
                                      color: _inkTertiary,
                                      size: 20,
                                    ),
                                    onPressed: () => _downloadAttachment(att),
                                  ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Activity Timeline Card ───────────────────────────────────
            _DetailCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.timeline_rounded,
                            color: _primary,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Activity Timeline',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const Spacer(),
                        if (_isFetchingDetails)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primary,
                            ),
                          )
                        else if (timeline.isNotEmpty)
                          _CountBadge(count: timeline.length, color: _primary),
                      ],
                    ),
                  ),
                  const _HDivider(),
                  if (_isFetchingDetails)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primary,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Loading timeline…',
                              style: TextStyle(
                                fontSize: 12,
                                color: _inkTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_fetchError != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _primary.withOpacity(0.35)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: _primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _fetchError!,
                                style: const TextStyle(
                                  color: _primary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (timeline.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: _inkTertiary,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'No activity yet',
                            style: TextStyle(color: _inkTertiary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        children: List.generate(timeline.length, (i) {
                          final act = timeline[i];
                          if (act is! Map) return const SizedBox.shrink();
                          final action = _str(
                            act['action'],
                            fallback: 'Activity',
                          );
                          final userName = _str(
                            act['user_name'] ??
                                act['performed_by'] ??
                                act['created_by'],
                            fallback: '',
                          );
                          final oldVal = act['old_value']?.toString();
                          final newVal = act['new_value']?.toString();
                          final timestamp = act['created_at']?.toString();
                          String? changeDesc;
                          if (oldVal != null &&
                              newVal != null &&
                              oldVal != 'null' &&
                              newVal != 'null') {
                            changeDesc =
                                '${_prettifyValue(oldVal)}  →  ${_prettifyValue(newVal)}';
                          }
                          final color = _activityColor(action);
                          final icon = _activityIcon(action);
                          final isLast = i == timeline.length - 1;
                          return _TimelineRow(
                            icon: icon,
                            color: color,
                            isLast: isLast,
                            action: action,
                            changeDesc: changeDesc,
                            performedBy:
                                (userName.isNotEmpty && userName != '—')
                                    ? userName
                                    : null,
                            formattedDate:
                                timestamp != null
                                    ? _formatDate(timestamp)
                                    : null,
                            timeAgo: _timeAgo(timestamp),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),

            // ── Status info pill (read-only) ─────────────────────────────
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _statusIcon(status),
                      color: statusColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Status',
                          style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _statusDescription(status),
                          style: const TextStyle(
                            fontSize: 12,
                            color: _inkSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(label: status, color: statusColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline Row (identical to CustomerViewScreen._TimelineRow)
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isLast;
  final String action;
  final String? changeDesc;
  final String? performedBy;
  final String? formattedDate;
  final String timeAgo;

  const _TimelineRow({
    required this.icon,
    required this.color,
    required this.isLast,
    required this.action,
    required this.timeAgo,
    this.changeDesc,
    this.performedBy,
    this.formattedDate,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withOpacity(0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(icon, color: color, size: 15),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          action,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      if (timeAgo.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          timeAgo,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF8A96A3),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (changeDesc != null && changeDesc!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Text(
                        changeDesc!,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                  if (performedBy != null && performedBy!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 12,
                          color: Color(0xFF8A96A3),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            performedBy!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8A96A3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (formattedDate != null && formattedDate!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      formattedDate!,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFFB0BAC9),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
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
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Highlight Text (matches CustomerTicketScreen._HighlightText)
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Small shared widgets
// ─────────────────────────────────────────────────────────────────────────────

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

// ── Detail-screen shared widgets (mirrors CustomerViewScreen) ─────────────────

class _DetailCard extends StatelessWidget {
  final Widget child;
  const _DetailCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE8ECF0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class _HDivider extends StatelessWidget {
  const _HDivider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: const Color(0xFFF0F4F8));
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.4), width: 1.2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.4,
          ),
        ),
      ],
    ),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _KVRow extends StatelessWidget {
  final String label;
  final String value;
  const _KVRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 110,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: _inkTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: _ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$count',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );
}
