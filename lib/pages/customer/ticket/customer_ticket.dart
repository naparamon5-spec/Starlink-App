import 'package:flutter/material.dart';
import '../../../components/Table.dart';
import '../../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'customer_ticket_modal.dart';
import 'customer_view.dart';
import '../../end-user/ticket/ticket_modal.dart';

class CustomerTicketScreen extends StatefulWidget {
  final bool showAppBar;

  const CustomerTicketScreen({super.key, this.showAppBar = true});

  @override
  _CustomerTicketState createState() => _CustomerTicketState();
}

class _CustomerTicketState extends State<CustomerTicketScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];
  bool _isLoading = true;
  int? _userId;

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
    final selectedStatus = _selectedFilter;

    setState(() {
      _filteredTickets =
          _tickets.where((ticket) {
            // Only show tickets with status OPEN or IN PROGRESS
            final status = ticket['Status']?.toString()?.toUpperCase() ?? '';
            final isOpenOrInProgress =
                status == 'OPEN' || status == 'IN PROGRESS';
            if (!isOpenOrInProgress) return false;
            // Filter by search query
            bool matchesQuery = true;
            if (query.isNotEmpty) {
              matchesQuery = _tableHeaders.any((header) {
                final value = ticket[header]?.toString().toLowerCase() ?? '';
                return value.contains(query);
              });
            }
            return matchesQuery;
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
    if (_filteredTickets.length <= _itemsPerPage)
      return const SizedBox.shrink();

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
    if (!mounted || _userId == null) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getTickets();

      if (response['status'] == 'success' && mounted) {
        setState(() {
          _tickets = List<Map<String, dynamic>>.from(
            response['data']
                .where((ticket) {
                  // Convert IDs to strings for comparison
                  String ticketContact = ticket['contact']?.toString() ?? '';
                  String ticketUserId = ticket['user_id']?.toString() ?? '';
                  String currentUserId = _userId.toString();
                  // Show tickets where this user is either the contact or the creator
                  bool isUserRelated =
                      ticketContact == currentUserId ||
                      ticketUserId == currentUserId;
                  // Only include tickets with status OPEN or IN PROGRESS
                  String backendStatus =
                      (ticket['status'] ?? '').toString().toLowerCase().trim();
                  bool isOpenOrInProgress =
                      backendStatus == 'open' ||
                      backendStatus == 'in progress' ||
                      backendStatus == 'in_progress' ||
                      backendStatus == 'inprogress';
                  return isUserRelated && isOpenOrInProgress;
                })
                .map((ticket) {
                  // Format attachments for display
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
                  String displayStatus;
                  String backendStatus =
                      (ticket['status'] ?? '').toString().toLowerCase().trim();

                  switch (backendStatus) {
                    case 'open':
                      displayStatus = 'OPEN';
                      break;
                    case 'in progress':
                    case 'in_progress':
                    case 'inprogress':
                      displayStatus = 'IN PROGRESS';
                      break;
                    case 'resolved':
                      displayStatus = 'RESOLVED';
                      break;
                    case 'closed':
                      displayStatus = 'CLOSED';
                      break;
                    default:
                      displayStatus = backendStatus.toUpperCase();
                  }

                  return {
                    'id': ticket['id'],
                    'Status': displayStatus,
                    'Ticket Type': ticket['type'] ?? 'N/A',
                    'Contact': ticket['contact_name'] ?? 'N/A',
                    'Subscription': ticket['subscription'] ?? 'N/A',
                    'Description': ticket['description'] ?? 'No description',
                    'Created At': _formatDate(ticket['created_at']),
                    'Attachments': attachmentsDisplay,
                    'full_data': {
                      ...ticket,
                      'created_at': _formatDate(ticket['created_at']),
                      'attachments': ticket['attachments'] ?? [],
                      'status': displayStatus,
                      'raw_status': backendStatus,
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

  void _showTicketDetails(Map<String, dynamic> ticket) {
    final fullData = ticket['full_data'] as Map<String, dynamic>;
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.6,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ticket Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF133343),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
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
                                    Builder(
                                      builder: (context) {
                                        final status =
                                            fullData['status']
                                                ?.toString()
                                                .toUpperCase() ??
                                            'OPEN';
                                        final statusColor = _getStatusColor(
                                          status,
                                        );
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: statusColor,
                                            ),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: statusColor,
                                            ),
                                          ),
                                        );
                                      },
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
                              fullData['attachments']
                                  .toString()
                                  .isNotEmpty) ...[
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
                                    ...(fullData['attachments'] as List).map((
                                      attachment,
                                    ) {
                                      if (attachment is Map) {
                                        final fileName =
                                            attachment['name']?.toString() ??
                                            'Unknown file';
                                        final fileType =
                                            attachment['type']?.toString() ??
                                            '';
                                        final fileSize = _formatFileSize(
                                          attachment['size'] as int?,
                                        );

                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8.0,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                _getFileIcon(fileType),
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).primaryColor,
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
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    if (fileSize.isNotEmpty)
                                                      Text(
                                                        fileSize,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600],
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
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Download functionality coming soon',
                                                      ),
                                                      duration: Duration(
                                                        seconds: 2,
                                                      ),
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
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.download,
                                            color: Color(0xFF133343),
                                          ),
                                          onPressed: () {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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

  void _showNewTicketModal() async {
    final result = await showDialog(
      context: context,
      builder:
          (dialogContext) => NewTicketModal(
            userId: _userId ?? 0,
            onConfirm: (ticket) {
              // Immediately add the new ticket to the list
              if (ticket['id'] != null && mounted) {
                setState(() {
                  // Format the ticket data to match the structure expected by _loadTickets
                  final newTicket = {
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
                      'contact': ticket['full_data']?['contact'],
                      'contact_name': ticket['Contact'] ?? 'N/A',
                      'subscription': ticket['Subscription'] ?? 'N/A',
                      'description': ticket['Description'] ?? 'No description',
                      'attachments': ticket['full_data']?['attachments'] ?? [],
                      'status': ticket['Status'] ?? 'OPEN',
                      'created_at':
                          ticket['Created At'] ??
                          _formatDate(DateTime.now().toString()),
                      'created_at_raw':
                          DateTime.tryParse(ticket['Created At'] ?? '') ??
                          DateTime.now(),
                      'user_id': ticket['full_data']?['user_id'],
                    },
                  };

                  // Insert at the beginning of the list
                  _tickets.insert(0, newTicket);
                  _filteredTickets = List.from(_tickets);
                  _currentPage = 1; // Reset to first page to show new ticket
                });
              }
            },
            onCancel: () {
              Navigator.of(dialogContext).pop();
            },
          ),
    );

    // Reload tickets to ensure consistency with backend
    if (result != null && mounted) {
      setState(() {
        _isLoading = true;
      });
      try {
        // Force refresh to get the latest data
        await _loadTickets();

        // Show success message
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
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void refreshTickets() {
    _loadTickets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text('My Tickets'),
                centerTitle: true,
                elevation: 2,
                backgroundColor: const Color(0xFF133343),
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(15),
                  ),
                ),
              )
              : null,
      body: Column(
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
                        style: TextStyle(color: Colors.grey[800], fontSize: 14),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedFilter = newValue;
                              _handleSearch();
                            });
                          }
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
                    : ListView.builder(
                      itemCount: _paginatedTickets.length,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemBuilder: (context, index) {
                        return _buildTicketCard(_paginatedTickets[index]);
                      },
                    ),
          ),
          if (_filteredTickets.length > _itemsPerPage)
            _buildPaginationControls(),
        ],
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

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final String ticketType = ticket['Ticket Type']?.toString() ?? 'N/A';
    final String createdAt = ticket['Created At']?.toString() ?? 'N/A';
    final String description =
        ticket['Description']?.toString() ?? 'No description';
    final String contact = ticket['Contact']?.toString() ?? 'N/A';
    final String subscription = ticket['Subscription']?.toString() ?? 'N/A';
    final String status = ticket['Status']?.toString() ?? 'OPEN';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          final Map<String, dynamic> ticketData = {
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
              builder: (context) => CustomerViewScreen(ticket: ticketData),
            ),
          ).then((result) {
            if (result != null && result is Map<String, dynamic>) {
              // If the ticket was closed or done, remove it from this list
              if (result['status']?.toString().toUpperCase() == 'CLOSED' ||
                  result['status']?.toString().toUpperCase() == 'RESOLVED') {
                setState(() {
                  _tickets.removeWhere(
                    (t) => t['id'].toString() == result['id'].toString(),
                  );
                  _filteredTickets = List.from(_tickets);
                });
              } else {
                // Update the ticket status in the list
                setState(() {
                  final ticketIndex = _tickets.indexWhere(
                    (t) => t['id'].toString() == result['id'].toString(),
                  );
                  if (ticketIndex != -1) {
                    _tickets[ticketIndex]['Status'] = result['status'];
                    if (_tickets[ticketIndex]['full_data'] != null) {
                      _tickets[ticketIndex]['full_data']['status'] =
                          result['status'];
                    }
                    // Update filtered tickets as well
                    _filteredTickets = List.from(_tickets);
                  }
                });
              }
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF133343),
                                ),
                              ),
                            ),
                            _buildStatusChip(status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Created: $createdAt',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
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
                        Text(
                          'Contact',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          contact,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subscription',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subscription,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Description',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildStatusChip(String status) {
    final Color statusColor = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(status), color: statusColor, size: 16),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
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
}
