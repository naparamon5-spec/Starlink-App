import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../components/Table.dart';
import 'ticket_modal.dart';
import '../../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ticket.dart';

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
      _userId = prefs.getInt('user_id')?.toString();
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

  Future<void> _loadTickets({bool forceRefresh = false}) async {
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

        if (!mounted) return;

        setState(() {
          // Process tickets and sort by creation date (newest first)
          _tickets = List<Map<String, dynamic>>.from(
            response['data'].map((ticket) {
              // Convert timestamps to readable format if needed
              String createdAt = ticket['created_at'] ?? 'N/A';
              DateTime? parsedDate;
              try {
                if (createdAt != 'N/A') {
                  parsedDate = DateTime.parse(createdAt);
                  createdAt =
                      '${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')} ${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}';
                }
              } catch (e) {
                print('Error parsing date: $e');
              }

              // Get agent name from the map using the contact ID
              final contactId = ticket['contact']?.toString() ?? '';
              final contactName = agentMap[contactId] ?? 'Not Assigned';

              // Process attachments
              String attachmentsDisplay = 'No attachments';
              if (ticket['attachments'] != null) {
                if (ticket['attachments'] is List) {
                  final attachments = List<dynamic>.from(ticket['attachments']);
                  if (attachments.isNotEmpty) {
                    attachmentsDisplay = attachments
                        .map((attachment) {
                          if (attachment is Map) {
                            return attachment['original_name']?.toString() ??
                                '';
                          } else if (attachment is String) {
                            return attachment;
                          }
                          return '';
                        })
                        .where((name) => name.isNotEmpty)
                        .join(', ');
                  }
                } else if (ticket['attachments'] is String) {
                  attachmentsDisplay = ticket['attachments'];
                }
              }

              final status = (ticket['status'] ?? 'open').toUpperCase();

              return {
                'id': ticket['id'],
                'type': ticket['type'] ?? 'N/A',
                'contact': contactName,
                'contact_id': ticket['contact'],
                'subscription': ticket['subscription'] ?? 'N/A',
                'description': ticket['description'] ?? 'No description',
                'attachments': attachmentsDisplay,
                'status': status,
                'created_at': createdAt,
                'created_at_raw': parsedDate, // Store raw date for sorting
                'user_id': ticket['user_id'],
                'full_data': {
                  ...ticket,
                  'status': status,
                  'created_at': createdAt,
                  'attachments': ticket['attachments'] ?? [],
                },
              };
            }),
          );

          // Sort tickets by creation date (newest first)
          _tickets.sort((a, b) {
            final dateA = a['created_at_raw'] as DateTime?;
            final dateB = b['created_at_raw'] as DateTime?;
            if (dateA == null || dateB == null) return 0;
            return dateB.compareTo(dateA);
          });

          // Update filtered tickets with a new list instance
          _filteredTickets = List.from(_tickets);
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

  Future<void> _updateTicketStatus(String ticketId, String newStatus) async {
    try {
      final response = await ApiService.updateTicketStatus(ticketId, newStatus);
      if (response['status'] == 'success') {
        setState(() {
          // Update the ticket status in both lists
          for (var ticket in _tickets) {
            if (ticket['id'].toString() == ticketId) {
              ticket['status'] = newStatus.toUpperCase();
              if (ticket['full_data'] != null) {
                ticket['full_data']['status'] = newStatus.toUpperCase();
              }
            }
          }
          for (var ticket in _filteredTickets) {
            if (ticket['id'].toString() == ticketId) {
              ticket['status'] = newStatus.toUpperCase();
              if (ticket['full_data'] != null) {
                ticket['full_data']['status'] = newStatus.toUpperCase();
              }
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket status updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
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
                  // Show loading indicator
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text('Creating ticket...'),
                        ],
                      ),
                      backgroundColor: Colors.blue,
                      duration: Duration(seconds: 30),
                    ),
                  );

                  print('Submitting ticket data: $newTicket');
                  final response = await ApiService.createTicket(newTicket);

                  if (!mounted) return;

                  // Check if response is null or invalid
                  if (response == null) {
                    throw Exception('No response from server');
                  }

                  // Check if response has the expected structure
                  if (response is! Map<String, dynamic>) {
                    throw Exception('Invalid response format from server');
                  }

                  if (response['status'] == 'success') {
                    // Clear the loading snackbar
                    ScaffoldMessenger.of(context).clearSnackBars();

                    // Close the modal first
                    Navigator.of(dialogContext).pop();

                    // Show refreshing indicator
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                            SizedBox(width: 16),
                            Text('Refreshing ticket list...'),
                          ],
                        ),
                        backgroundColor: Colors.blue,
                        duration: Duration(seconds: 10),
                      ),
                    );

                    // Reset filters and search
                    setState(() {
                      _selectedFilter = 'All';
                      _currentPage = 1;
                      _searchController.clear();
                    });

                    // Force a complete reload of tickets
                    await _loadTickets(forceRefresh: true);

                    // Ensure the UI is updated with the new data
                    if (mounted) {
                      setState(() {
                        // Force rebuild of the list by creating new instances
                        _filteredTickets = List.from(_tickets);
                      });

                      // Additional UI refresh to ensure the list is updated
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            // Force another rebuild after the frame
                          });
                        }
                      });
                    }

                    // Clear the refreshing snackbar
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).clearSnackBars();

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ticket created successfully'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  } else {
                    final errorMessage =
                        response['message'] ?? 'Failed to create ticket';
                    throw Exception(errorMessage);
                  }
                } catch (e) {
                  print('Error creating ticket: $e');
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error creating ticket: ${e.toString()}'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                    ),
                  );
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TicketDetailsScreen(ticket: ticket),
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
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Implement notifications
            },
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
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Create new ticket',
      ),
    );
  }
}
