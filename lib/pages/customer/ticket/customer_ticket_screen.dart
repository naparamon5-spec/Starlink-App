import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'customer_view.dart';

class CustomerTicketHistory extends StatefulWidget {
  final bool showAppBar;

  const CustomerTicketHistory({super.key, this.showAppBar = true});

  @override
  _CustomerTicketScreenState createState() => _CustomerTicketScreenState();
}

class _CustomerTicketScreenState extends State<CustomerTicketHistory>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];
  bool _isLoading = true;
  int? _userId;

  final List<String> _filterOptions = ['All', 'DONE', 'CLOSED'];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _searchController.addListener(_handleSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearch);
    _searchController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId != null) {
        setState(() {
          _userId = userId;
        });
        _loadTickets();
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  void _handleSearch() {
    final query = _searchController.text.toLowerCase();
    final selectedStatus = _selectedFilter;

    setState(() {
      _filteredTickets =
          _tickets.where((ticket) {
            bool matchesFilter = true;
            if (selectedStatus != 'All') {
              final ticketStatus =
                  ticket['status']?.toString().toUpperCase() ?? '';
              matchesFilter = ticketStatus == selectedStatus;
            }

            bool matchesQuery = true;
            if (query.isNotEmpty) {
              matchesQuery = ticket.values.any(
                (value) => value.toString().toLowerCase().contains(query),
              );
            }

            return matchesFilter && matchesQuery;
          }).toList();
    });
  }

  Future<void> _loadTickets() async {
    if (!mounted || _userId == null) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getTickets();

      if (response['status'] == 'success' && mounted) {
        setState(() {
          _tickets = List<Map<String, dynamic>>.from(
            response['data']
                .where((ticket) {
                  final status =
                      (ticket as Map<String, dynamic>)['status']
                          ?.toString()
                          ?.toLowerCase() ??
                      '';
                  final contactId =
                      (ticket as Map<String, dynamic>)['contact']?.toString() ??
                      '';
                  final userIdField =
                      (ticket as Map<String, dynamic>)['user_id']?.toString() ??
                      '';
                  final currentUserId = _userId.toString();
                  // Show tickets where this user is either the contact or the creator and status is RESOLVED or CLOSED
                  final isUserRelated =
                      contactId == currentUserId ||
                      userIdField == currentUserId;
                  final isResolvedOrClosed =
                      status == 'resolved' || status == 'closed';
                  return isUserRelated && isResolvedOrClosed;
                })
                .map((ticket) {
                  final Map<String, dynamic> ticketData =
                      Map<String, dynamic>.from(ticket);
                  String attachmentsDisplay = 'No attachments';
                  if (ticketData['attachments'] != null &&
                      ticketData['attachments'].isNotEmpty) {
                    if (ticketData['attachments'] is List) {
                      final fileNames =
                          (ticketData['attachments'] as List)
                              .where((attachment) => attachment != null)
                              .map((attachment) {
                                if (attachment is Map) {
                                  return attachment['name']?.toString() ?? '';
                                }
                                return '';
                              })
                              .where((name) => name.isNotEmpty)
                              .toList();
                      attachmentsDisplay =
                          fileNames.isNotEmpty
                              ? fileNames.join(', ')
                              : 'No attachments';
                    } else if (ticketData['attachments'] is String) {
                      attachmentsDisplay = ticketData['attachments'].toString();
                    }
                  }
                  // Map backend status to display status
                  String displayStatus;
                  String backendStatus =
                      (ticketData['status'] ?? '')
                          .toString()
                          .toLowerCase()
                          .trim();
                  // Map status to display format
                  if (backendStatus == 'resolved') {
                    displayStatus = 'RESOLVED';
                  } else if (backendStatus == 'closed' ||
                      backendStatus == 'close') {
                    displayStatus = 'CLOSED';
                  } else {
                    displayStatus = backendStatus.toUpperCase();
                  }
                  return {
                    'id': ticketData['id'],
                    'type': ticketData['type'] ?? 'N/A',
                    'status': displayStatus,
                    'subscription': ticketData['subscription'] ?? 'N/A',
                    'description':
                        ticketData['description'] ?? 'No description',
                    'created_at': _formatDate(ticketData['created_at']),
                    'attachments': attachmentsDisplay,
                    'full_data': {
                      ...ticketData,
                      'created_at': _formatDate(ticketData['created_at']),
                      'attachments': ticketData['attachments'] ?? [],
                      'status': displayStatus,
                    },
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
      print('Error loading tickets: ${e.toString()}');
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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return Colors.green;
      case 'IN PROGRESS':
        return Colors.orange;
      case 'RESOLVED':
        return Colors.blue;
      case 'CLOSED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return Icons.radio_button_unchecked;
      case 'IN PROGRESS':
        return Icons.hourglass_empty;
      case 'RESOLVED':
        return Icons.check_circle_outline;
      case 'CLOSED':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket History'),
        centerTitle: true,
        elevation: 2,
        backgroundColor: const Color(0xFF133343),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _tickets.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.history,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No resolved or closed tickets found',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _tickets.length,
                      itemBuilder: (context, index) {
                        final ticket = _tickets[index];
                        final status =
                            ticket['status'].toString().toUpperCase();
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            leading: Icon(
                              _getStatusIcon(status),
                              color: _getStatusColor(status),
                            ),
                            title: Text(
                              ticket['type'] ?? 'N/A',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ticket['description'] ?? 'No description'),
                                const SizedBox(height: 4),
                                Text(
                                  'Created: ${ticket['created_at']}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getStatusColor(status),
                                ),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          CustomerViewScreen(ticket: ticket),
                                ),
                              ).then((result) {
                                if (result != null &&
                                    result is Map<String, dynamic>) {
                                  if (result['status']
                                              ?.toString()
                                              .toUpperCase() ==
                                          'RESOLVED' ||
                                      result['status']
                                              ?.toString()
                                              .toUpperCase() ==
                                          'CLOSED' ||
                                      result['forceRefresh'] == true) {
                                    _loadTickets();
                                  } else {
                                    setState(() {
                                      final ticketIndex = _tickets.indexWhere(
                                        (t) =>
                                            t['id'].toString() ==
                                            result['id'].toString(),
                                      );
                                      if (ticketIndex != -1) {
                                        _tickets[ticketIndex]['status'] =
                                            result['status'];
                                        if (_tickets[ticketIndex]['full_data'] !=
                                            null) {
                                          _tickets[ticketIndex]['full_data']['status'] =
                                              result['status'];
                                        }
                                      }
                                    });
                                  }
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
