import 'dart:convert';
import 'package:flutter/material.dart';
import '../../components/Table.dart';
import 'ticket_modal.dart';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './ticket.dart';

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

  // Pagination variables
  int _itemsPerPage = 6;
  int _currentPage = 1;

  // Updated filter options to match backend ticket_type values
  final List<String> _filterOptions = [
    'All',
    'Billing',
    'Connection Issue',
    'Request for Off/On',
    'Request for Reactivate',
    'Request for Deactivate',
    'Device/Kit/Router Issue',
  ];

  // Mapping frontend filter options to backend ticket_type for accurate filtering
  final Map<String, String> _filterToTicketType = {
    'All': 'All',
    'Billing': 'Billing',
    'Connection Issue': 'Connection Issue',
    'Request for Off/On': 'Request for Off/On',
    'Request for Reactivate': 'Request for Reactivate',
    'Request for Deactivate': 'Request for Deactivate',
    'Device/Kit/Router Issue': 'Device/Kit/Router Issue',
  };

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
    _loadTickets();
    _searchController.addListener(_handleSearch);
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
      _userId = prefs.getString('userId');
    });
  }

  void _handleSearch() {
    final query = _searchController.text.toLowerCase();
    final selectedTicketType = _selectedFilter;

    setState(() {
      _filteredTickets =
          _tickets.where((ticket) {
            // Filter by ticket type
            bool matchesFilter = true;
            if (selectedTicketType != 'All') {
              final ticketType = ticket['type']?.toString().toLowerCase() ?? '';
              matchesFilter = ticketType == selectedTicketType.toLowerCase();
            }

            // Filter by search query
            bool matchesQuery = true;
            if (query.isNotEmpty) {
              matchesQuery =
                  ticket['type']?.toString().toLowerCase().contains(query) ??
                  false;
            }

            return matchesFilter && matchesQuery;
          }).toList();

      // Reset to first page when search/filter changes
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

  Future<void> _loadTickets() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getTickets();

      if (response['status'] == 'success' && mounted) {
        // First, get the list of agents to map IDs to names
        final agentsResponse = await ApiService.getAgents();
        final agentMap = Map.fromEntries(
          (agentsResponse['data'] as List).map(
            (agent) =>
                MapEntry(agent['id'].toString(), agent['name'] as String),
          ),
        );

        setState(() {
          _tickets = List<Map<String, dynamic>>.from(
            response['data'].map((ticket) {
              // Convert timestamps to readable format if needed
              String createdAt = ticket['created_at'] ?? 'N/A';
              try {
                if (createdAt != 'N/A') {
                  final date = DateTime.parse(createdAt);
                  createdAt =
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                }
              } catch (e) {
                print('Error parsing date: $e');
              }

              // Get agent name from the map using the contact ID
              final contactId = ticket['contact']?.toString() ?? '';
              final contactName = agentMap[contactId] ?? 'Not Assigned';

              // Get attachments and display original file names
              String displayAttachments = 'No attachments';
              if (ticket['attachments'] != null &&
                  ticket['attachments'].toString().isNotEmpty) {
                try {
                  if (ticket['attachments'] is List) {
                    final fileNames =
                        ticket['attachments']
                            .where((attachment) => attachment != null)
                            .map((attachment) {
                              if (attachment is Map) {
                                return attachment['name']?.toString() ?? '';
                              } else if (attachment is String) {
                                return attachment;
                              }
                              return '';
                            })
                            .where((name) => name.isNotEmpty)
                            .toList();

                    displayAttachments =
                        fileNames.isNotEmpty
                            ? fileNames.join(', ')
                            : 'No attachments';
                  } else if (ticket['attachments'] is String) {
                    final fileNames =
                        ticket['attachments']
                            .split(',')
                            .map((name) => name.trim())
                            .where((name) => name.isNotEmpty)
                            .toList();

                    displayAttachments =
                        fileNames.isNotEmpty
                            ? fileNames.join(', ')
                            : 'No attachments';
                  }
                } catch (e) {
                  print('Error processing attachments: $e');
                  print('Raw attachments data: ${ticket['attachments']}');
                  displayAttachments = 'Error displaying attachments';
                }
              }

              return {
                'id': ticket['id'],
                'type': ticket['type'] ?? 'N/A',
                'contact': contactName,
                'subscription': ticket['subscription'] ?? 'N/A',
                'description': ticket['description'] ?? 'No description',
                'attachments': displayAttachments,
                'status': (ticket['status'] ?? 'open').toUpperCase(),
                'created_at': createdAt,
              };
            }),
          );
          _filteredTickets = _tickets;
          _isLoading = false;
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to load tickets');
      }
    } catch (e) {
      print('Error loading tickets: $e');
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

  void _showNewTicketModal() {
    if (_userId == null || _userId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: User not logged in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Parse user ID with validation
    int? parsedUserId;
    try {
      parsedUserId = int.parse(_userId!);
    } catch (e) {
      print('Error parsing user ID: $_userId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Invalid user ID'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (BuildContext dialogContext) => WillPopScope(
            onWillPop: () async => false,
            child: NewTicketModal(
              userId: parsedUserId!,
              onConfirm: (newTicket) async {
                try {
                  print('Submitting ticket data: $newTicket');
                  final response = await ApiService.createTicket(newTicket);

                  if (!mounted) return;

                  if (response['status'] == 'success') {
                    // First refresh the tickets list
                    await _loadTickets();

                    // Then close the modal
                    if (mounted) {
                      Navigator.of(dialogContext).pop();

                      // Show success message after modal is closed
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Ticket created successfully'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  } else {
                    throw Exception(
                      response['message'] ?? 'Failed to create ticket',
                    );
                  }
                } catch (e) {
                  print('Error creating ticket: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error creating ticket: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              onCancel: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final String ticketType = ticket['type']?.toString() ?? 'N/A';
    final String createdAt = ticket['created_at']?.toString() ?? 'N/A';
    final String status = ticket['status']?.toString().toUpperCase() ?? 'N/A';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TicketDetailsScreen(ticket: ticket),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
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
                    Text(
                      ticketType,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF133343),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created: $createdAt',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      status == 'OPEN'
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: status == 'OPEN' ? Colors.green : Colors.red,
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: status == 'OPEN' ? Colors.green : Colors.red,
                  ),
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
        title: const Text('Tickets'),
        centerTitle: true,
        elevation: 2,
        backgroundColor: const Color(0xFF133343),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(color: Colors.grey[50]),
        child: Column(
          children: [
            // Search and filter bar
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
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search tickets...',
                          prefixIcon: Icon(
                            Icons.search,
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
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
                          ),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedFilter = newValue!;
                              _currentPage =
                                  1; // Reset to first page on filter change
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredTickets.isEmpty
                      ? Center(
                        child: Text(
                          _tickets.isEmpty
                              ? 'No tickets found. Create a new ticket to get started.'
                              : 'No tickets match your search.',
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0, right: 16.0),
        child: FloatingActionButton(
          onPressed: _showNewTicketModal,
          backgroundColor: const Color(0xFF133343),
          child: const Icon(Icons.add, color: Colors.white),
          tooltip: 'Create new ticket',
          elevation: 10,
        ),
      ),
    );
  }
}
