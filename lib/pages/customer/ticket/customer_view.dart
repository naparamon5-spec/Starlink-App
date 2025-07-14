import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CustomerViewScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;

  const CustomerViewScreen({super.key, required this.ticket});

  @override
  _CustomerViewScreenState createState() => _CustomerViewScreenState();
}

class _CustomerViewScreenState extends State<CustomerViewScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];
  bool _isLoading = true;
  int? _userId;
  bool _isAccepted = false;

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _searchController.addListener(_handleSearch);
  }

  @override
  void didUpdateWidget(CustomerViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh tickets when the widget updates
    if (widget.ticket != oldWidget.ticket) {
      _loadTickets();
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearch);
    _searchController.dispose();
    super.dispose();
  }

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
    final selectedType = _selectedFilter;

    setState(() {
      _filteredTickets =
          _tickets.where((ticket) {
            // Filter by ticket type
            bool matchesFilter = true;
            if (selectedType != 'All') {
              matchesFilter =
                  ticket['type'].toString().toLowerCase() ==
                  selectedType.toLowerCase();
            }

            // Filter by search query
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
                  // Show tickets where this user is the contact and status is DONE, COMPLETED, or CLOSED
                  final status =
                      ticket['status']?.toString()?.toLowerCase() ?? '';
                  return ticket['contact'] == _userId &&
                      (status == 'done' ||
                          status == 'completed' ||
                          status == 'closed');
                })
                .map((ticket) {
                  String attachmentsDisplay = 'No attachments';
                  if (ticket['attachments'] != null &&
                      ticket['attachments'].isNotEmpty) {
                    if (ticket['attachments'] is List) {
                      final fileNames =
                          (ticket['attachments'] as List)
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
                    } else if (ticket['attachments'] is String) {
                      attachmentsDisplay = ticket['attachments'].toString();
                    }
                  }

                  // Map backend status to display status
                  String displayStatus = 'OPEN';
                  String backendStatus =
                      (ticket['status'] ?? 'open')
                          .toString()
                          .toLowerCase()
                          .trim();

                  if (backendStatus == 'open' || backendStatus == 'opened') {
                    displayStatus = 'OPEN';
                  } else if (backendStatus == 'in progress' ||
                      backendStatus == 'in_progress' ||
                      backendStatus == 'inprogress') {
                    displayStatus = 'IN PROGRESS';
                  } else if (backendStatus == 'resolved' ||
                      backendStatus == 'done' ||
                      backendStatus == 'completed') {
                    displayStatus = 'RESOLVED';
                  } else if (backendStatus == 'closed' ||
                      backendStatus == 'close') {
                    displayStatus = 'CLOSED';
                  } else {
                    displayStatus = backendStatus.toUpperCase();
                  }

                  return {
                    'id': ticket['id'],
                    'type': ticket['type'] ?? 'N/A',
                    'status': displayStatus,
                    'subscription': ticket['subscription'] ?? 'N/A',
                    'description': ticket['description'] ?? 'No description',
                    'created_at': _formatDate(ticket['created_at']),
                    'attachments': attachmentsDisplay,
                    'full_data': {
                      ...ticket,
                      'created_at': _formatDate(ticket['created_at']),
                      'attachments': ticket['attachments'] ?? [],
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

  Future<void> _acceptTicket() async {
    try {
      final response = await ApiService.updateTicketStatus(
        widget.ticket['id'].toString(),
        'in progress',
      );

      if (response['status'] == 'success') {
        setState(() {
          _isAccepted = true;
          widget.ticket['status'] = 'IN PROGRESS';
          if (widget.ticket['full_data'] != null) {
            widget.ticket['full_data']['status'] = 'IN PROGRESS';
          }
        });
        await _saveInProgressTicketData(widget.ticket);

        // Store notification in the database for ticket acceptance
        print('DEBUG: Ticket object: ${widget.ticket}');
        final recipientUserId =
            widget.ticket['user_id'] ??
            (widget.ticket['full_data'] != null
                ? widget.ticket['full_data']['user_id']
                : null) ??
            widget.ticket['contact'] ??
            widget.ticket['customer_id'];
        print('DEBUG: Using recipientUserId: $recipientUserId');
        final acceptancePayload = {
          'user_id': recipientUserId,
          'title': 'Ticket Accepted',
          'message':
              'Ticket #${widget.ticket['id']} (${widget.ticket['type']}) has been accepted by ${widget.ticket['contact_name'] ?? 'Customer'}',
          'type': 'ticket_accepted',
          'icon': 'check_circle',
          'color': '#4CAF50',
          'data': {
            'ticket_id': widget.ticket['id'],
            'ticket_type': widget.ticket['type'],
            'customer_name': widget.ticket['contact_name'],
            'action': 'ticket_accepted',
          },
        };
        print(
          'DEBUG: Acceptance notification payload: ' +
              acceptancePayload.toString(),
        );
        await NotificationService.createCustomerNotification(acceptancePayload);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ticket accepted successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Pop back to the ticket screen and trigger a refresh with the new status
          Navigator.pop(context, {
            'status': 'IN PROGRESS',
            'id': widget.ticket['id'].toString(),
          });

          await _setTicketInProgress(widget.ticket['id'].toString());
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to accept ticket');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting ticket: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resolveTicket() async {
    try {
      final response = await ApiService.updateTicketStatus(
        widget.ticket['id'].toString(),
        'resolved',
      );

      if (response['status'] == 'success') {
        setState(() {
          widget.ticket['status'] = 'RESOLVED';
          if (widget.ticket['full_data'] != null) {
            widget.ticket['full_data']['status'] = 'RESOLVED';
          }
        });

        // Store notification in the database for ticket resolution
        print('DEBUG: Ticket object: ${widget.ticket}');
        final resolveRecipientUserId =
            widget.ticket['user_id'] ??
            (widget.ticket['full_data'] != null
                ? widget.ticket['full_data']['user_id']
                : null) ??
            widget.ticket['contact'] ??
            widget.ticket['customer_id'];
        print('DEBUG: Using recipientUserId: $resolveRecipientUserId');
        final resolvePayload = {
          'user_id': resolveRecipientUserId,
          'title': 'Ticket Resolved',
          'message':
              'Ticket #${widget.ticket['id']} (${widget.ticket['type']}) has been resolved by ${widget.ticket['contact_name'] ?? 'Customer'}',
          'type': 'ticket_resolved',
          'icon': 'task_alt',
          'color': '#2196F3',
          'data': {
            'ticket_id': widget.ticket['id'],
            'ticket_type': widget.ticket['type'],
            'customer_name': widget.ticket['contact_name'],
            'action': 'ticket_resolved',
          },
        };
        print(
          'DEBUG: Resolve notification payload: ' + resolvePayload.toString(),
        );
        await NotificationService.createCustomerNotification(resolvePayload);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ticket marked as resolved successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Pop back to the ticket screen with updated status and force refresh
          Navigator.pop(context, {
            'status': 'RESOLVED',
            'id': widget.ticket['id'].toString(),
            'shouldRefresh': true,
            'forceRefresh': true,
          });

          await _removeTicketInProgress(widget.ticket['id'].toString());
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to resolve ticket');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resolving ticket: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _closeTicket() async {
    try {
      final response = await ApiService.updateTicketStatus(
        widget.ticket['id'].toString(),
        'closed',
      );

      if (response['status'] == 'success') {
        setState(() {
          widget.ticket['status'] = 'CLOSED';
          if (widget.ticket['full_data'] != null) {
            widget.ticket['full_data']['status'] = 'closed';
          }
        });

        // Store notification in the database for ticket closure
        print('DEBUG: Ticket object: ${widget.ticket}');
        final closeRecipientUserId =
            widget.ticket['user_id'] ??
            (widget.ticket['full_data'] != null
                ? widget.ticket['full_data']['user_id']
                : null) ??
            widget.ticket['contact'] ??
            widget.ticket['customer_id'];
        print('DEBUG: Using recipientUserId: $closeRecipientUserId');
        final closePayload = {
          'user_id': closeRecipientUserId,
          'title': 'Ticket Closed',
          'message':
              'Ticket #${widget.ticket['id']} (${widget.ticket['type']}) has been closed by ${widget.ticket['contact_name'] ?? 'Customer'}',
          'type': 'ticket_closed',
          'icon': 'cancel',
          'color': '#F44336',
          'data': {
            'ticket_id': widget.ticket['id'],
            'ticket_type': widget.ticket['type'],
            'customer_name': widget.ticket['contact_name'],
            'action': 'ticket_closed',
          },
        };
        print('DEBUG: Close notification payload: ' + closePayload.toString());
        await NotificationService.createCustomerNotification(closePayload);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ticket closed successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Pop back to the ticket screen and trigger a refresh
          Navigator.pop(context, {
            'status': 'CLOSED',
            'id': widget.ticket['id'].toString(),
          });

          await _removeTicketInProgress(widget.ticket['id'].toString());
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to close ticket');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error closing ticket: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateTicketStatus(String ticketId, String newStatus) async {
    try {
      final response = await ApiService.updateTicketStatus(ticketId, newStatus);
      if (response['status'] == 'success') {
        setState(() {
          widget.ticket['status'] = newStatus.toUpperCase();
          if (widget.ticket['full_data'] != null) {
            widget.ticket['full_data']['status'] = newStatus;
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ticket status updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating ticket status: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    List<String> ids = await _getInProgressTicketIds();
    if (!ids.contains(ticketId)) {
      ids.add(ticketId);
      await _saveInProgressTicketIds(ids);
    }
  }

  Future<void> _removeTicketInProgress(String ticketId) async {
    List<String> ids = await _getInProgressTicketIds();
    ids.remove(ticketId);
    await _saveInProgressTicketIds(ids);
  }

  Future<void> _saveInProgressTicketData(Map<String, dynamic> ticket) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> rawList =
        prefs.getStringList('in_progress_tickets_data') ?? [];
    // Remove any existing entry for this ticket
    rawList.removeWhere((item) {
      final data = jsonDecode(item);
      return data['id'].toString() == ticket['id'].toString();
    });
    rawList.add(jsonEncode(ticket));
    await prefs.setStringList('in_progress_tickets_data', rawList);
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final fullData = ticket['full_data'] as Map<String, dynamic>;
    String status = fullData['status']?.toString().toUpperCase() ?? 'OPEN';
    if (status.trim().isEmpty) status = 'OPEN';
    print('Ticket status in UI: $status');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket Details'),
        centerTitle: true,
        elevation: 2,
        backgroundColor: const Color(0xFF133343),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    'Ticket Type',
                    fullData['type'] ?? 'N/A',
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildDetailItem(
                    'Subscription',
                    fullData['subscription'] ?? 'N/A',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF133343),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _getStatusColor(status)),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: _getStatusColor(status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildDetailItem(
                    'Created At',
                    fullData['created_at'] ?? 'N/A',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Description',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF133343),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                fullData['description'] ?? 'No description',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            if (fullData['attachments'] != null &&
                fullData['attachments'].toString().isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Attachments',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF133343),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (fullData['attachments'] is List) ...[
                      ...(fullData['attachments'] as List).map((attachment) {
                        if (attachment is Map) {
                          final fileName =
                              attachment['name']?.toString() ?? 'Unknown file';
                          final fileType = attachment['type']?.toString() ?? '';
                          final fileSize = _formatFileSize(
                            attachment['size'] as int?,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                  _getFileIcon(fileType),
                                  color: Theme.of(context).primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fileName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (fileSize.isNotEmpty)
                                        Text(
                                          fileSize,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.download,
                                    color: Color(0xFF133343),
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Download functionality coming soon',
                                        ),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  tooltip: 'Download file',
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }).toList(),
                    ] else ...[
                      Row(
                        children: [
                          Icon(
                            Icons.attach_file,
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              fullData['attachments'].toString(),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.download,
                              color: Color(0xFF133343),
                            ),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Download functionality coming soon',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            tooltip: 'Download file',
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (!_isAccepted && status == 'OPEN')
              Center(
                child: ElevatedButton(
                  onPressed: _acceptTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF133343),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Accept Ticket',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            if ((_isAccepted || status == 'IN PROGRESS') &&
                status != 'RESOLVED' &&
                status != 'CLOSED') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _resolveTicket,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Resolve Ticket',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _closeTicket,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Close Ticket',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF133343),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(value, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }

  String _formatFileSize(int? size) {
    if (size == null) return '';
    return '${(size / 1024).toStringAsFixed(1)} KB';
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return Colors.green;
      case 'IN PROGRESS':
        return Colors.orange;
      case 'RESOLVED':
      case 'RESOLVE':
        return Colors.blue;
      case 'CLOSED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
