import 'dart:convert';
import 'package:flutter/material.dart';
import '../../components/Table.dart';
import 'ticket_modal.dart';
import '../services/api_service.dart';

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

  // Updated filter options to match backend ticket_type values
  final List<String> _filterOptions = [
    'All',
    'Billing',
    'Connection Issue', // Matches API ticket_type
    'Request for Off/On',
    'Request for Reactivate',
    'Request for Deactivate',
    'Device/Kit/Router Issue', // Matches API ticket_type
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
    'type', // Matches 'type' in data
    'contact', // Matches 'contact' in data
    'subscription', // Matches 'subscription' in data
    'description', // Matches 'description' in data
    'attachments', // Matches 'attachments' in data
  ];

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _searchController.addListener(_handleSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch() {
    final query = _searchController.text.toLowerCase();
    final selectedTicketType = _filterToTicketType[_selectedFilter] ?? 'All';

    print(
      'Search query: $query, Selected filter: $_selectedFilter, Mapped type: $selectedTicketType',
    ); // Debug log

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
              matchesQuery = _tableHeaders.any((header) {
                final value = ticket[header]?.toString().toLowerCase() ?? '';
                return value.contains(query);
              });
            }

            return matchesFilter && matchesQuery;
          }).toList();

      print('Filtered tickets count: ${_filteredTickets.length}'); // Debug log
    });
  }

  Future<void> _loadTickets() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getTickets();

      if (response['status'] == 'success' && mounted) {
        setState(() {
          _tickets = List<Map<String, dynamic>>.from(response['data']);
          _filteredTickets = _tickets;
          _isLoading = false;
        });
        print('Loaded ${_tickets.length} tickets successfully');
        print(
          'First ticket data: ${_tickets.isNotEmpty ? _tickets.first : 'No tickets'}',
        );
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

  Future<void> _showNewTicketModal() async {
    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder:
            (BuildContext context) => NewTicketModal(
              onConfirm: (Map<String, dynamic> newTicket) async {
                try {
                  final response = await ApiService.createTicket({
                    'type': newTicket['type'],
                    'contact': newTicket['contact'],
                    'subscription': newTicket['subscription'],
                    'description': newTicket['description'],
                  });

                  if (response['status'] == 'success') {
                    if (!mounted) return;
                    await _loadTickets(); // Reload tickets after successful creation
                    Navigator.of(context).pop(newTicket);
                  } else {
                    throw Exception(
                      response['message'] ?? 'Failed to create ticket',
                    );
                  }
                } catch (e) {
                  print('Error adding ticket: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error creating ticket: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              onCancel: () => Navigator.of(context).pop(null),
            ),
      );

      if (result != null && mounted) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF133343),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Success!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ticket created successfully',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          color: Color(0xFF133343),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      print('Error showing modal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error showing modal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                              _handleSearch(); // Trigger filter update
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Stack(
                          children: [
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child:
                                    _filteredTickets.isEmpty
                                        ? Center(
                                          child: Text(
                                            _tickets.isEmpty
                                                ? 'No tickets found. Create a new ticket to get started.'
                                                : 'No tickets match your search.',
                                          ),
                                        )
                                        : ReusableTable(
                                          headers: _tableHeaders,
                                          data: _filteredTickets,
                                        ),
                              ),
                            ),
                          ],
                        ),
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
