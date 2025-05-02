import 'dart:convert';
import 'package:flutter/material.dart';
import '../../components/Table.dart';
import 'ticket_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key});

  @override
  _TicketScreenState createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = true;

  final List<String> _tableHeaders = [
    'Type',
    'Contact',
    'Subscription',
    'Description',
    'Attachments',
  ];

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? ticketsJson = prefs.getString('tickets');
      if (ticketsJson != null) {
        final List<dynamic> decoded = jsonDecode(ticketsJson);
        if (!mounted) return;

        setState(() {
          _tickets = List<Map<String, dynamic>>.from(
            decoded.map((item) => Map<String, dynamic>.from(item)),
          );
          _isLoading = false;
        });
        print('Loaded ${_tickets.length} tickets successfully');
      } else {
        if (!mounted) return;
        setState(() {
          _tickets = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading tickets: $e');
      if (!mounted) return;
      setState(() {
        _tickets = [];
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

  Future<bool> _saveTickets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(_tickets);
      await prefs.setString('tickets', encoded);
      return true;
    } catch (e) {
      print('Error saving tickets: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving ticket: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
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
                  if (!mounted) return;

                  setState(() {
                    _tickets = [
                      ..._tickets,
                      Map<String, dynamic>.from(newTicket),
                    ];
                  });

                  final saved = await _saveTickets();
                  if (saved) {
                    Navigator.of(context).pop(newTicket);
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
        // Force rebuild of the table with new data
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error showing modal: $e');
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
                    // ignore: deprecated_member_use
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
                            });
                          },
                          items:
                              <String>[
                                'All',
                                'Open',
                                'Closed',
                                'Pending',
                              ].map<DropdownMenuItem<String>>((String value) {
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
                    'All Tickets (${_tickets.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child:
                                _tickets.isEmpty
                                    ? const Center(
                                      child: Text(
                                        'No tickets found. Create a new ticket to get started.',
                                      ),
                                    )
                                    : ReusableTable(
                                      headers: _tableHeaders,
                                      data: _tickets,
                                    ),
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0, right: 16.0),
        child: FloatingActionButton.extended(
          onPressed: _showNewTicketModal,
          backgroundColor: const Color(0xFF133343),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'New Ticket',
            style: TextStyle(color: Colors.white),
          ),
          tooltip: 'Create new ticket',
          elevation: 10,
        ),
      ),
    );
  }
}
