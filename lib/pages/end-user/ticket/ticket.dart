import 'package:flutter/material.dart';
import '../../../components/Table.dart';
import '../../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

// Top-level function for mapping serviceLineNumber to nickname
String getNickname(
  List<Map<String, dynamic>> subscriptions,
  String? serviceLineNumber,
) {
  if (serviceLineNumber == null) return 'N/A';
  final sub = subscriptions.firstWhere(
    (s) => s['serviceLineNumber'].toString() == serviceLineNumber.toString(),
    orElse: () => {},
  );
  return sub['nickname'] ?? serviceLineNumber;
}

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
  Map<String, dynamic>? _selectedTicket;
  List<Map<String, dynamic>> _subscriptions = [];

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

  final List<String> _tableHeaders = [
    'Status',
    'Contact',
    'Subscription',
    'Ticket Type',
    'Attachments',
  ];

  @override
  void initState() {
    super.initState();
    _loadSubscriptionsAndTickets();
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
    final selectedType = _selectedFilter;

    setState(() {
      _filteredTickets =
          _tickets.where((ticket) {
            // Filter by ticket type
            bool matchesFilter = true;
            if (selectedType != 'All') {
              matchesFilter =
                  ticket['Ticket Type'].toString().toLowerCase() ==
                  selectedType.toLowerCase();
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
    });
  }

  Future<void> _loadSubscriptionsAndTickets() async {
    // Fetch all subscriptions for mapping
    final subsResponse = await ApiService.getSubscriptions();
    if (subsResponse['status'] == 'success') {
      _subscriptions = List<Map<String, dynamic>>.from(subsResponse['data']);
    }
    await _loadTickets();
  }

  Future<void> _loadTickets() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.getTickets();

      if (response['status'] == 'success' && mounted) {
        setState(() {
          _tickets = List<Map<String, dynamic>>.from(
            response['data'].map((ticket) {
              // Process attachments
              String attachmentsDisplay = 'No attachments';
              List<dynamic> attachments = [];

              if (ticket['attachments'] != null) {
                attachmentsDisplay = ticket['attachments'].toString();
                attachments = [
                  {'original_name': ticket['attachments']},
                ];
              }

              // Map backend status to display status
              String displayStatus = 'OPEN';
              String backendStatus =
                  (ticket['status'] ?? 'open').toString().toLowerCase().trim();

              if (backendStatus == 'open' || backendStatus == 'opened') {
                displayStatus = 'OPEN';
              } else if (backendStatus == 'in progress' ||
                  backendStatus == 'in_progress' ||
                  backendStatus == 'inprogress') {
                displayStatus = 'IN PROGRESS';
              } else if (backendStatus == 'done') {
                displayStatus = 'DONE';
              } else if (backendStatus == 'closed') {
                displayStatus = 'CLOSED';
              }

              // Compose contact name from user_first_name and user_name
              String contactName =
                  ticket['user_first_name'] ??
                  ticket['user_name'] ??
                  ticket['user_id']?.toString() ??
                  'Not Assigned';

              final processedTicket = {
                'id': ticket['id'],
                'Status': displayStatus,
                'name': contactName,
                'Contact': contactName,
                'Subscription': getNickname(
                  _subscriptions,
                  ticket['subscription'],
                ),
                'Ticket Type': ticket['type'] ?? 'N/A',
                'Attachments': attachmentsDisplay,
                'full_data': {
                  ...ticket,
                  'created_at': _formatDate(ticket['created_at']),
                  'attachments': attachments,
                  'contact': ticket['user_id'],
                  'contact_name': contactName,
                  'status': displayStatus,
                  'subscription_nickname': getNickname(
                    _subscriptions,
                    ticket['subscription'],
                  ),
                },
              };

              return processedTicket;
            }),
          );
          _filteredTickets = _tickets;
          _isLoading = false;
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to load tickets');
      }
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

  String _formatFileSize(dynamic size) {
    if (size == null) return '';
    final double sizeInBytes = size is int ? size.toDouble() : size as double;
    if (sizeInBytes < 1024) {
      return '${sizeInBytes.toStringAsFixed(1)} B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  Future<void> _updateTicketStatus(String ticketId, String newStatus) async {
    try {
      final response = await ApiService.updateTicketStatus(ticketId, newStatus);
      if (response['status'] == 'success') {
        setState(() {
          _selectedTicket!['status'] = newStatus.toUpperCase();
          if (_selectedTicket!['full_data'] != null) {
            _selectedTicket!['full_data']['status'] = newStatus.toUpperCase();
          }
        });

        // Pop back to ticket list screen with updated status
        Navigator.pop(context, {
          'status': newStatus.toUpperCase(),
          'id': ticketId,
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
                                  'Contact',
                                  fullData['contact_name']?.toString() ??
                                      fullData['name']?.toString() ??
                                      'Not Assigned',
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _buildDetailItem(
                                  'Subscription',
                                  getNickname(
                                    _subscriptions,
                                    fullData['subscription'],
                                  ),
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
                                        color: _getStatusColor(
                                          fullData['status']
                                                  ?.toString()
                                                  .toUpperCase() ??
                                              'OPEN',
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _getStatusColor(
                                            fullData['status']
                                                    ?.toString()
                                                    .toUpperCase() ??
                                                'OPEN',
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        fullData['status']
                                                ?.toString()
                                                .toUpperCase() ??
                                            'OPEN',
                                        style: TextStyle(
                                          color: _getStatusColor(
                                            fullData['status']
                                                    ?.toString()
                                                    .toUpperCase() ??
                                                'OPEN',
                                          ),
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
                                            attachment['original_name']
                                                ?.toString() ??
                                            attachment['file_name']
                                                ?.toString() ??
                                            'Unknown file';

                                        final fileType =
                                            attachment['file_type']
                                                ?.toString() ??
                                            fileName.split('.').last;

                                        final fileSize = _formatFileSize(
                                          attachment['file_size'] as int?,
                                        );

                                        final fileId =
                                            attachment['id']?.toString();

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
                                                        '$fileType • $fileSize',
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
                                                onPressed: () async {
                                                  if (fileId != null) {
                                                    try {
                                                      final response =
                                                          await http.get(
                                                            Uri.parse(
                                                              '${ApiService.baseUrl}/api.php?action=download_attachment&attachment_id=$fileId',
                                                            ),
                                                          );

                                                      if (response.statusCode ==
                                                          200) {
                                                        String?
                                                        contentDisposition =
                                                            response
                                                                .headers['content-disposition'];
                                                        String fileName =
                                                            'downloaded_file';
                                                        if (contentDisposition !=
                                                            null) {
                                                          final matches = RegExp(
                                                            r'filename="(.+?)"',
                                                          ).firstMatch(
                                                            contentDisposition,
                                                          );
                                                          if (matches != null &&
                                                              matches.groupCount >=
                                                                  1) {
                                                            fileName =
                                                                matches.group(
                                                                  1,
                                                                )!;
                                                          }
                                                        }

                                                        final directory =
                                                            await getApplicationDocumentsDirectory();
                                                        final file = File(
                                                          '${directory.path}/$fileName',
                                                        );
                                                        await file.writeAsBytes(
                                                          response.bodyBytes,
                                                        );

                                                        if (mounted) {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                'File downloaded to: ${file.path}',
                                                              ),
                                                              duration:
                                                                  const Duration(
                                                                    seconds: 3,
                                                                  ),
                                                            ),
                                                          );
                                                        }
                                                      } else {
                                                        throw Exception(
                                                          'Failed to download file',
                                                        );
                                                      }
                                                    } catch (e) {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Error downloading file: $e',
                                                            ),
                                                            backgroundColor:
                                                                Colors.red,
                                                            duration:
                                                                const Duration(
                                                                  seconds: 3,
                                                                ),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  } else {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Download not available for this file',
                                                        ),
                                                        duration: Duration(
                                                          seconds: 2,
                                                        ),
                                                      ),
                                                    );
                                                  }
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
    ).then((result) async {
      if (result != null && result is Map<String, dynamic>) {
        setState(() {
          final ticketIndex = _tickets.indexWhere(
            (t) => t['id'].toString() == result['id'].toString(),
          );
          if (ticketIndex != -1) {
            _tickets[ticketIndex]['Status'] = result['status'];
            if (_tickets[ticketIndex]['full_data'] != null) {
              _tickets[ticketIndex]['full_data']['status'] = result['status'];
            }
            _filteredTickets = List.from(_tickets);
          }
        });

        await _loadTickets();
      }
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return Colors.green;
      case 'IN PROGRESS':
        return Colors.orange;
      case 'DONE':
        return Colors.blue;
      case 'CLOSED':
        return Colors.red;
      default:
        return Colors.grey;
    }
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
      ),
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
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Card(
                      margin: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child:
                            _filteredTickets.isEmpty
                                ? const Center(child: Text('No tickets found'))
                                : ReusableTable(
                                  headers: _tableHeaders,
                                  data: _filteredTickets,
                                  onRowTap: _showTicketDetails,
                                ),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class TicketDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final List<Map<String, dynamic>> subscriptions;

  const TicketDetailsScreen({
    Key? key,
    required this.ticket,
    required this.subscriptions,
  }) : super(key: key);

  @override
  _TicketDetailsScreenState createState() => _TicketDetailsScreenState();
}

class _TicketDetailsScreenState extends State<TicketDetailsScreen> {
  late Map<String, dynamic> _ticket;
  late List<Map<String, dynamic>> _subscriptions;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
    _subscriptions = widget.subscriptions;
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return Colors.green;
      case 'IN PROGRESS':
        return Colors.orange;
      case 'DONE':
        return Colors.blue;
      case 'CLOSED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDetailItem(String label, String? value) {
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
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(value ?? 'N/A', style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }

  String _formatFileSize(dynamic size) {
    if (size == null) return '';
    final double sizeInBytes = size is int ? size.toDouble() : size as double;
    if (sizeInBytes < 1024) {
      return '${sizeInBytes.toStringAsFixed(1)} B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _ticket['status']?.toString().toUpperCase() ?? 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ticket Details',
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
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Ticket Type and Status
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _ticket['type']?.toString() ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF133343),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Created: ${_ticket['created_at']?.toString() ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
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
              const SizedBox(height: 32),
              // Ticket Information
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ticket Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF133343),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              'Contact',
                              _ticket['contact_name']?.toString() ??
                                  _ticket['name']?.toString() ??
                                  'Not Assigned',
                            ),
                          ),

                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildDetailItem(
                              'Subscription',
                              getNickname(
                                _subscriptions,
                                _ticket['subscription']?.toString(),
                              ),
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
                          _ticket['description']?.toString() ??
                              'No description',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Attachments Section
              _buildAttachmentsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    final attachments = _ticket['attachments'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attachments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF133343),
              ),
            ),
            const SizedBox(height: 24),
            if (attachments != null && attachments.isNotEmpty) ...[
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
                    if (attachments is List) ...[
                      ...(attachments as List).map((attachment) {
                        String fileName;
                        String fileType = '';
                        String fileSize = '';
                        String? fileId;

                        if (attachment is Map) {
                          fileName =
                              attachment['original_name']?.toString() ??
                              attachment['file_name']?.toString() ??
                              attachment['name']?.toString() ??
                              'Unknown file';
                          fileType =
                              attachment['file_type']?.toString() ??
                              attachment['type']?.toString() ??
                              fileName.split('.').last;
                          fileSize = _formatFileSize(
                            attachment['size'] ?? attachment['file_size'],
                          );
                          fileId = attachment['id']?.toString();
                        } else if (attachment is String) {
                          fileName = attachment;
                          fileType = attachment.split('.').last;
                        } else {
                          fileName = 'Unknown file';
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            children: [
                              Icon(
                                _getFileIcon(fileType),
                                color: Theme.of(context).primaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fileName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (fileSize.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        '$fileType • $fileSize',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.download,
                                  color: Color(0xFF133343),
                                ),
                                onPressed: () async {
                                  if (fileId != null) {
                                    try {
                                      final response = await http.get(
                                        Uri.parse(
                                          '${ApiService.baseUrl}/api.php?action=download_attachment&attachment_id=$fileId',
                                        ),
                                      );

                                      if (response.statusCode == 200) {
                                        String? contentDisposition =
                                            response
                                                .headers['content-disposition'];
                                        String fileName = 'downloaded_file';
                                        if (contentDisposition != null) {
                                          final matches = RegExp(
                                            r'filename="(.+?)"',
                                          ).firstMatch(contentDisposition);
                                          if (matches != null &&
                                              matches.groupCount >= 1) {
                                            fileName = matches.group(1)!;
                                          }
                                        }

                                        final directory =
                                            await getApplicationDocumentsDirectory();
                                        final file = File(
                                          '${directory.path}/$fileName',
                                        );
                                        await file.writeAsBytes(
                                          response.bodyBytes,
                                        );

                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'File downloaded to: ${file.path}',
                                              ),
                                              duration: const Duration(
                                                seconds: 3,
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        throw Exception(
                                          'Failed to download file',
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error downloading file: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                            duration: const Duration(
                                              seconds: 3,
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Download not available for this file',
                                        ),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                tooltip: 'Download file',
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ] else if (attachments is String) ...[
                      Row(
                        children: [
                          Icon(
                            _getFileIcon(attachments.split('.').last),
                            color: Theme.of(context).primaryColor,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              attachments,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Text(
                  'No attachments',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }
}
