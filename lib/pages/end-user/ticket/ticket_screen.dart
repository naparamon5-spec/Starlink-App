import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../components/Table.dart';
import '../../../components/notification_badge.dart';
import '../profile/notifications.dart';
import 'ticket_modal.dart';
import '../../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ticket.dart';
import 'package:provider/provider.dart';
import '../../../providers/notification_provider.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key});

  @override
  _TicketScreenState createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];
  bool _isLoading = true;
  String? _userId;
  List<Map<String, dynamic>> _subscriptions = [];

  // Pagination variables
  int _itemsPerPage = 6;
  int _currentPage = 1;

  List<String> _filterOptions = ['All'];
  Map<String, String> _filterToTicketType = {'All': 'All'};

  final List<String> _tableHeaders = [
    'Ticket Type',
    'Contact',
    'Subscription',
    'Description',
    'Attachments',
    'Status',
    'Created At',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCategoriesAndTickets();
    _searchController.addListener(_handleSearch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<NotificationProvider>(
        context,
        listen: false,
      );
      provider.refresh();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearch);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getInt('user_id')?.toString();
    });
  }

  void _handleSearch() {
    final query = _searchController.text.toLowerCase();
    final selectedTicketType = _selectedFilter;

    setState(() {
      _filteredTickets =
          _tickets.where((ticket) {
            bool matchesFilter = true;
            if (selectedTicketType != 'All') {
              final ticketType =
                  (ticket['type']?.toString() ?? '').toLowerCase().trim();
              final filterType =
                  (_filterToTicketType[selectedTicketType]
                          ?.toLowerCase()
                          .trim() ??
                      '');
              matchesFilter = ticketType == filterType;
            }

            bool matchesQuery = true;
            if (query.isNotEmpty) {
              matchesQuery = ticket.values.any(
                (value) =>
                    value != null &&
                    value.toString().toLowerCase().contains(query),
              );
            }

            return matchesFilter && matchesQuery;
          }).toList();

      _currentPage = 1;
    });
  }

  List<Map<String, dynamic>> get _paginatedTickets {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _filteredTickets.length) {
      _currentPage = 1;
      return _filteredTickets.take(_itemsPerPage).toList();
    }
    return _filteredTickets.sublist(
      startIndex,
      endIndex > _filteredTickets.length ? _filteredTickets.length : endIndex,
    );
  }

  int get _totalPages => (_filteredTickets.length / _itemsPerPage).ceil();

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                _currentPage > 1 ? () => setState(() => _currentPage--) : null,
            color: const Color(0xFF133343),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Text(
              'Page $_currentPage of $_totalPages',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF133343),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed:
                _currentPage < _totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
            color: const Color(0xFF133343),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSubscriptionsAndTickets() async {
    try {
      final subscriptions = await ApiService.getSubscriptions();
      _subscriptions =
          subscriptions.isNotEmpty
              ? List<Map<String, dynamic>>.from(subscriptions)
              : [];
    } catch (e) {
      debugPrint('Error loading subscriptions: $e');
      _subscriptions = [];
    }

    await _loadTickets();
  }

  Future<void> _loadCategoriesAndTickets() async {
    try {
      // FIX: getCategories() returns Map<String, dynamic> — access ['status'] and ['data']
      final categoriesResponse = await ApiService.getCategories();

      if (categoriesResponse['status'] == 'success' &&
          categoriesResponse['data'] != null) {
        final categoryList = List<Map<String, dynamic>>.from(
          (categoriesResponse['data'] as List)
              .whereType<Map<String, dynamic>>(),
        );

        setState(() {
          _filterOptions = [
            'All',
            ...categoryList
                .map((c) => c['name']?.toString() ?? '')
                .where((name) => name.isNotEmpty),
          ];
          _filterToTicketType = {'All': 'All'};
          for (final c in categoryList) {
            final name = c['name']?.toString() ?? '';
            if (name.isNotEmpty) {
              _filterToTicketType[name] = name;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }

    await _loadSubscriptionsAndTickets();
  }

  Future<void> _loadTickets({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      List<Map<String, dynamic>> allTickets = [];
      int page = 1;
      const int limit = 50;
      bool hasMore = true;

      while (hasMore) {
        final response = await ApiService.getTickets(page: page, limit: limit);

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

      final contacts = await ApiService.getContacts();
      final agentMap = Map.fromEntries(
        contacts.map(
          (contact) => MapEntry(
            contact['id'].toString(),
            contact['name']?.toString() ?? '',
          ),
        ),
      );

      final List<Map<String, dynamic>> loadedTickets =
          allTickets.map((ticket) {
            String createdAt = ticket['created_at'] ?? 'N/A';
            DateTime? parsedDate;

            try {
              if (createdAt != 'N/A') {
                parsedDate = DateTime.parse(createdAt);
                createdAt =
                    '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')} '
                    '${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}';
              }
            } catch (_) {}

            final contactId = ticket['contact']?.toString() ?? '';
            final contactName = agentMap[contactId] ?? '';

            return {
              'id': ticket['id'],
              'type': ticket['ticket_type'] ?? ticket['type'] ?? 'N/A',
              'contact': contactName,
              'contact_id': ticket['contact'],
              'subscription': ticket['subscription_id'] ?? '',
              'description': ticket['description'] ?? '',
              'attachments': ticket['attachments'] ?? [],
              'status': (ticket['status'] ?? 'open').toString().toUpperCase(),
              'created_at': createdAt,
              'created_at_raw': parsedDate,
              'user_id': ticket['user_id'],
              'full_data': ticket,
            };
          }).toList();

      if (!mounted) return;

      setState(() {
        _tickets = loadedTickets;
        _filteredTickets = List.from(_tickets);
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
          content: Text('Error loading tickets: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateTicketStatus(String ticketId, String newStatus) async {
    try {
      final response = await ApiService.updateTicketStatus(ticketId, newStatus);
      if (response['status'] == 'success') {
        setState(() {
          for (var ticket in _tickets) {
            if (ticket['id'].toString() == ticketId) {
              ticket['status'] = newStatus.toUpperCase();
              ticket['full_data']?['status'] = newStatus.toUpperCase();
            }
          }
          for (var ticket in _filteredTickets) {
            if (ticket['id'].toString() == ticketId) {
              ticket['status'] = newStatus.toUpperCase();
              ticket['full_data']?['status'] = newStatus.toUpperCase();
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket status updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        if (newStatus.toUpperCase() == 'IN PROGRESS') {
          await _setTicketInProgress(ticketId);
        } else if (newStatus.toUpperCase() == 'RESOLVED' ||
            newStatus.toUpperCase() == 'CLOSED') {
          await _removeTicketInProgress(ticketId);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating ticket status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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

  // FIX: added missing getNickname helper (was called as top-level function before)
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
      builder:
          (dialogContext) => NewTicketModal(
            userId: int.parse(_userId ?? '0'),
            onConfirm: (ticket) {
              debugPrint(
                'onConfirm ticket: Contact = \'${ticket['Contact']}\', '
                'contact_name = \'${ticket['full_data']?['contact_name']}\'',
              );
              if (ticket['id'] != null && mounted) {
                setState(() {
                  final serviceLineNumber =
                      ticket['full_data']?['subscription']?.toString();
                  // FIX: use instance method instead of undefined top-level function
                  final subscriptionNickname = _getNickname(
                    _subscriptions,
                    serviceLineNumber,
                  );
                  final contactName =
                      ticket['Contact'] ??
                      ticket['full_data']?['contact_name'] ??
                      '';
                  final newTicket = {
                    'id': ticket['id'],
                    'type': ticket['Ticket Type'] ?? 'N/A',
                    'contact': contactName,
                    'contact_name': contactName,
                    'contact_id': ticket['full_data']?['contact'],
                    'subscription': subscriptionNickname,
                    'serviceLineNumber': serviceLineNumber,
                    'description': ticket['Description'] ?? 'No description',
                    'attachments': ticket['Attachments'] ?? 'No attachments',
                    'status': ticket['Status'] ?? 'OPEN',
                    'created_at':
                        ticket['Created At'] ??
                        _formatDate(DateTime.now().toString()),
                    'created_at_raw':
                        DateTime.tryParse(ticket['Created At'] ?? '') ??
                        DateTime.now(),
                    'user_id': ticket['full_data']?['user_id'],
                    'full_data': {
                      ...ticket['full_data'],
                      'status': ticket['Status'] ?? 'OPEN',
                      'created_at':
                          ticket['Created At'] ??
                          _formatDate(DateTime.now().toString()),
                      'attachments': ticket['full_data']?['attachments'] ?? [],
                      'subscription_nickname': subscriptionNickname,
                      'serviceLineNumber': serviceLineNumber,
                      'contact_name': contactName,
                    },
                  };
                  debugPrint('newTicket contact: \'${newTicket['contact']}\'');
                  _tickets.insert(0, newTicket);
                  _filteredTickets = List.from(_tickets);
                  _currentPage = 1;
                });
              }
            },
            onCancel: () {
              Navigator.of(dialogContext).pop();
            },
          ),
    );

    if (result != null && mounted) {
      setState(() => _isLoading = true);
      try {
        await _loadTickets(forceRefresh: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket created successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error refreshing tickets: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final String ticketType = ticket['type']?.toString() ?? 'N/A';
    final String createdAt = ticket['created_at']?.toString() ?? 'N/A';
    final String status = ticket['status']?.toString() ?? 'OPEN';

    Color statusColor;
    switch (status.toUpperCase()) {
      case 'OPEN':
        statusColor = Colors.green;
        break;
      case 'CLOSED':
        statusColor = Colors.red;
        break;
      case 'IN PROGRESS':
        statusColor = Colors.orange;
        break;
      case 'RESOLVED':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      elevation: 2,
      shadowColor: const Color(0xFF133343).withOpacity(0.1),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          debugPrint('Tapped ticket: $ticket');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      TicketDetailsScreen(ticket: ticket, subscriptions: []),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF133343).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.confirmation_number_outlined,
                  color: Color(0xFF133343),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ticketType,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF133343),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: statusColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created: $createdAt',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        letterSpacing: 0.2,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tickets',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF133343),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          NotificationBadge(
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Colors.grey[50]!],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search tickets...',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            letterSpacing: 0.3,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedFilter,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down),
                          iconSize: 20,
                          elevation: 16,
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 14,
                            letterSpacing: 0.3,
                          ),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedFilter = newValue!;
                              _currentPage = 1;
                              _handleSearch();
                            });
                          },
                          items:
                              _filterOptions.map<DropdownMenuItem<String>>((
                                String value,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All Tickets (${_filteredTickets.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF133343),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF133343),
                          ),
                          strokeWidth: 3,
                        ),
                      )
                      : _filteredTickets.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _tickets.isEmpty
                                    ? Icons.confirmation_number_outlined
                                    : Icons.search_off_outlined,
                                color: Colors.grey,
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _tickets.isEmpty
                                  ? 'No tickets found. Create a new ticket to get started.'
                                  : 'No tickets match your search.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                      : Column(
                        children: [
                          Expanded(
                            child: ListView.builder(
                              itemCount: _paginatedTickets.length,
                              padding: const EdgeInsets.only(top: 8),
                              itemBuilder: (context, index) {
                                return _buildTicketCard(
                                  _paginatedTickets[index],
                                );
                              },
                            ),
                          ),
                          if (_filteredTickets.length > _itemsPerPage)
                            _buildPaginationControls(),
                        ],
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewTicketModal,
        backgroundColor: const Color(0xFF133343),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        tooltip: 'Create new ticket',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
