import 'package:flutter/material.dart';
import '../../../components/Table.dart';
import '../../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'customer_ticket_modal.dart';

class CustomerTicketScreen extends StatefulWidget {
  final bool showAppBar;

  const CustomerTicketScreen({super.key, this.showAppBar = true});

  @override
  _CustomerTicketScreenState createState() => _CustomerTicketScreenState();
}

class _CustomerTicketScreenState extends State<CustomerTicketScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];
  bool _isLoading = true;
  int? _userId;

  // Pagination variables
  int _itemsPerPage = 6;
  int _currentPage = 1;

  // Filter options for customer view
  final List<String> _filterOptions = ['All', 'Open', 'Closed'];

  final List<String> _tableHeaders = [
    'Status',
    'Ticket Type',
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
            // Filter by status
            bool matchesFilter = true;
            if (selectedStatus != 'All') {
              matchesFilter =
                  ticket['Status'].toString().toLowerCase() ==
                  selectedStatus.toLowerCase();
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
                .where((ticket) => ticket['user_id'] == _userId)
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

                  return {
                    'id': ticket['id'],
                    'Status': (ticket['status'] ?? 'open').toUpperCase(),
                    'Ticket Type': ticket['type'] ?? 'N/A',
                    'Description': ticket['description'] ?? 'No description',
                    'Created At': _formatDate(ticket['created_at']),
                    'Attachments': attachmentsDisplay,
                    // Store all data for detailed view
                    'full_data': {
                      ...ticket,
                      'created_at': _formatDate(ticket['created_at']),
                      'attachments': ticket['attachments'] ?? [],
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
                                  'Status',
                                  fullData['status']
                                          ?.toString()
                                          .toUpperCase() ??
                                      'N/A',
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

  void showNewTicketModal() {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID not found. Please try again later.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => CustomerTicketModal(
            userId: _userId!,
            onConfirm: (newTicket) async {
              try {
                final response = await ApiService.createTicket(newTicket);
                if (response['status'] == 'success') {
                  Navigator.of(context).pop();
                  _loadTickets();
                } else {
                  throw Exception(
                    response['message'] ?? 'Failed to create ticket',
                  );
                }
              } catch (e) {
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
            onCancel: () => Navigator.of(context).pop(),
          ),
    );
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
                    : Column(
                      children: [
                        Expanded(
                          child: Card(
                            margin: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ReusableTable(
                                headers: _tableHeaders,
                                data: _paginatedTickets,
                                onRowTap: _showTicketDetails,
                              ),
                            ),
                          ),
                        ),
                        _buildPaginationControls(),
                      ],
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showNewTicketModal,
        backgroundColor: const Color(0xFF133343),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
