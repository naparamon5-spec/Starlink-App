import 'package:flutter/material.dart';
import '../../../components/Table.dart';
import '../../../services/api_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

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

  /// Holds the API status `value` e.g. "open", "in_progress".
  /// 'All' means no filter.
  String _selectedFilter = 'All';

  List<Map<String, dynamic>> _tickets = [];
  List<Map<String, dynamic>> _filteredTickets = [];
  bool _isLoading = true;
  Map<String, dynamic>? _selectedTicket;
  List<Map<String, dynamic>> _subscriptions = [];

  /// Each entry: { 'value': 'in_progress', 'label': 'In Progress' }
  /// Populated entirely from the API — zero hardcoded statuses.
  List<Map<String, dynamic>> _statusFilters = [];

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
    _loadCategoriesAndTickets();
    _searchController.addListener(_handleSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearch);
    _searchController.dispose();
    super.dispose();
  }

  // ── Normalize raw API status value → display string ───────────────────────
  // e.g. "in_progress" → "IN PROGRESS", "open" → "OPEN"
  String _normalizeStatus(String raw) {
    return raw.replaceAll('_', ' ').toUpperCase();
  }

  // ── Search + filter ───────────────────────────────────────────────────────
  void _handleSearch() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredTickets =
          _tickets.where((ticket) {
            // Status filter — _selectedFilter holds raw API value e.g. "in_progress"
            // ticket['Status'] is already normalized e.g. "IN PROGRESS"
            bool matchesFilter = true;
            if (_selectedFilter != 'All') {
              final ticketStatus = ticket['Status']?.toString() ?? '';
              final filterNormalized = _normalizeStatus(_selectedFilter);
              matchesFilter = ticketStatus == filterNormalized;
            }

            // Text search across table columns
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

  // ── Load filters from API ─────────────────────────────────────────────────
  Future<void> _loadCategoriesAndTickets() async {
    try {
      debugPrint('🔵 [FILTERS] Fetching ticket filters...');
      final res = await ApiService.getTicketFilters();
      debugPrint('🔵 [FILTERS] Raw response: $res');

      // API response shape:
      // { "data": { "statuses": [ { "value": "open", "label": "Open" }, ... ] } }
      final data = res['data'];
      final statuses = data is Map ? (data['statuses'] ?? []) : [];

      if (statuses is List && statuses.isNotEmpty) {
        final parsed =
            statuses
                .whereType<Map>()
                .map(
                  (s) => {
                    'value': s['value']?.toString() ?? '',
                    'label': s['label']?.toString() ?? '',
                  },
                )
                .where((s) => s['value']!.isNotEmpty && s['label']!.isNotEmpty)
                .toList();

        debugPrint('✅ [FILTERS] Loaded ${parsed.length} statuses: $parsed');
        setState(() => _statusFilters = parsed);
      } else {
        debugPrint('⚠️  [FILTERS] No statuses found in response');
      }
    } catch (e) {
      debugPrint('🔴 [FILTERS] Exception: $e');
    }

    await _loadSubscriptionsAndTickets();
  }

  // ── Load subscriptions ────────────────────────────────────────────────────
  Future<void> _loadSubscriptionsAndTickets() async {
    try {
      final subsList = await ApiService.getSubscriptions();
      _subscriptions = subsList.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      _subscriptions = [];
    }
    await _loadTickets();
  }

  // ── Load tickets ──────────────────────────────────────────────────────────
  Future<void> _loadTickets() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.getTickets();
      if (!mounted) return;

      setState(() {
        _tickets = List<Map<String, dynamic>>.from(
          response['data'].map((ticket) {
            // Attachments
            String attachmentsDisplay = 'No attachments';
            List<dynamic> attachments = [];
            if (ticket['attachments'] != null) {
              attachmentsDisplay = ticket['attachments'].toString();
              attachments = [
                {'original_name': ticket['attachments']},
              ];
            }

            // Normalize status from raw API value → uppercase display string
            final rawStatus = (ticket['status'] ?? 'open').toString().trim();
            final displayStatus = _normalizeStatus(rawStatus);

            // Contact name
            String contactName =
                ticket['contact_name']?.toString() ??
                ticket['contact']?.toString() ??
                'Not Assigned';

            return {
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
          }),
        );
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
          final normalized = newStatus.replaceAll('_', ' ').toUpperCase();
          // Update selected ticket if present
          if (_selectedTicket != null) {
            _selectedTicket!['status'] = normalized;
            if (_selectedTicket!['full_data'] != null) {
              _selectedTicket!['full_data']['status'] = normalized;
            }
          }

          // Update list rows by id
          final idx = _tickets.indexWhere(
            (t) => t['id']?.toString() == ticketId.toString(),
          );
          if (idx != -1) {
            _tickets[idx]['Status'] = normalized;
            if (_tickets[idx]['full_data'] != null) {
              _tickets[idx]['full_data']['status'] = normalized;
            }
            _filteredTickets = List.from(_tickets);
          }
        });

        Navigator.pop(context, {
          'status': newStatus.replaceAll('_', ' ').toUpperCase(),
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

  Future<void> _showAddCommentComposer(BuildContext dialogContext, String ticketId) async {
    final id = ticketId.trim();
    if (id.isEmpty) return;
    final controller = TextEditingController();
    bool posting = false;

    await showModalBottomSheet<void>(
      context: dialogContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            final canPost = controller.text.trim().isNotEmpty && !posting;

            Future<void> post() async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              setSheetState(() => posting = true);
              final res = await ApiService.addTicketComment(id, text);
              setSheetState(() => posting = false);

              if (!ctx.mounted) return;
              if (res['status'] == 'success') {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Comment added.'),
                    backgroundColor: Colors.green,
                  ),
                );
                await _loadTickets();
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      res['message']?.toString() ?? 'Failed to add comment.',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF133343).withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.add_comment_outlined,
                                color: Color(0xFF133343),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Add a comment',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: posting ? null : () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: TextField(
                            controller: controller,
                            autofocus: true,
                            minLines: 3,
                            maxLines: 6,
                            textInputAction: TextInputAction.newline,
                            onChanged: (_) => setSheetState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Write something helpful…',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${controller.text.trim().length}/1000',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: canPost ? post : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEB1E23),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (posting) ...[
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  const Text(
                                    'Post Comment',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTicketDetails(Map<String, dynamic> ticket) {
    // Keep a reference to allow status updates without null errors.
    _selectedTicket = ticket;
    final fullData = ticket['full_data'] as Map<String, dynamic>;
    debugPrint(fullData.toString());

    String normalizeStatus(String raw) {
      return raw.replaceAll('_', ' ').toUpperCase().trim();
    }

    final ticketId = fullData['id']?.toString() ?? ticket['id']?.toString() ?? '';
    final status = normalizeStatus(fullData['status']?.toString() ?? 'OPEN');
    final isOpen = status == 'OPEN';
    final isInProgress = status == 'IN PROGRESS';

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
                  if (ticketId.isNotEmpty && (isOpen || isInProgress)) ...[
                    Row(
                      children: [
                        if (isOpen)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  () => _updateTicketStatus(
                                    ticketId,
                                    'in_progress',
                                  ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF133343),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Accept Ticket',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        if (isInProgress) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  () =>
                                      _updateTicketStatus(ticketId, 'resolved'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF24A148),
                                side: const BorderSide(
                                  color: Color(0xFF24A148),
                                  width: 1.2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.verified_outlined, size: 18),
                              label: const Text(
                                'Resolve',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  () =>
                                      _updateTicketStatus(ticketId, 'closed'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEB1E23),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.lock_outline_rounded, size: 18),
                              label: const Text(
                                'Close',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
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
                                      'Not Assigned',
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _buildDetailItem(
                                  'Subscription',
                                  getNickname(
                                    _subscriptions,
                                    fullData['subscription']?.toString(),
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
                                  fullData['created_at']?.toString() ?? 'N/A',
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
                              fullData['description']?.toString() ??
                                  'No description',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Comments',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF133343),
                                  ),
                                ),
                              ),
                              if (isInProgress && ticketId.isNotEmpty)
                                InkWell(
                                  onTap:
                                      () => _showAddCommentComposer(
                                        context,
                                        ticketId,
                                      ),
                                  borderRadius: BorderRadius.circular(999),
                                  child: Ink(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF133343)
                                          .withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: const Color(0xFF133343)
                                            .withOpacity(0.14),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add_comment_outlined,
                                          size: 18,
                                          color: Color(0xFF133343),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Comment',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            letterSpacing: 0.2,
                                            color: Color(0xFF133343),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (ticketId.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: const Text(
                                'Ticket ID not available.',
                                style: TextStyle(fontSize: 14),
                              ),
                            )
                          else
                            FutureBuilder<Map<String, dynamic>>(
                              future: ApiService.getTicketComments(ticketId),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: const Row(
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text('Loading comments...'),
                                      ],
                                    ),
                                  );
                                }

                                if (snapshot.hasError) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: Text(
                                      'Failed to load comments: ${snapshot.error}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }

                                final res = snapshot.data ?? {};
                                final ok = res['status'] == 'success';
                                final data = ok ? res['data'] : null;
                                final list =
                                    data is List ? data : (data is Map ? data['data'] : null);
                                final items = (list is List) ? list : const [];

                                if (items.isEmpty) {
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: const Text(
                                      'No comments yet.',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  );
                                }

                                return Column(
                                  children: items.map((e) {
                                    if (e is! Map) return const SizedBox.shrink();
                                    final name = e['name']?.toString() ?? '—';
                                    final dateRaw = e['date']?.toString();
                                    final comment = e['comment']?.toString() ?? '';
                                    return Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.grey[300]!),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF133343),
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                _formatDate(dateRaw),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            comment.trim().isEmpty
                                                ? '—'
                                                : comment.trim(),
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          if (fullData['attachments'] != null &&
                              fullData['attachments'].toString().isNotEmpty &&
                              fullData['attachments'].toString() != '[]') ...[
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
                                          attachment['file_size'],
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
                                                onPressed:
                                                    () => _downloadAttachment(
                                                      context,
                                                      fileId,
                                                    ),
                                                tooltip: 'Download file',
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    }),
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

  /// Shared download helper
  Future<void> _downloadAttachment(BuildContext ctx, String? fileId) async {
    if (fileId == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Download not available for this file'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    try {
      final response = await ApiService.downloadAttachment(fileId);
      if (response['status'] == 'success') {
        final fileName = response['filename']?.toString().trim();
        final base64Str = response['base64']?.toString().trim();
        if (fileName == null ||
            fileName.isEmpty ||
            base64Str == null ||
            base64Str.isEmpty) {
          throw Exception('Server returned invalid attachment data.');
        }
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(base64Decode(base64Str));

        if (mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text('File downloaded to: ${file.path}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception(
          response['message']?.toString() ?? 'Failed to download file',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Error downloading file: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ── Status chip color — keyed on API value via reverse-lookup ─────────────
  Color _getStatusColor(String normalizedStatus) {
    final match = _statusFilters.firstWhere(
      (s) => _normalizeStatus(s['value'] ?? '') == normalizedStatus,
      orElse: () => {},
    );
    final value =
        match.isNotEmpty
            ? match['value']?.toString() ?? ''
            : normalizedStatus.toLowerCase().replaceAll(' ', '_');

    switch (value) {
      case 'open':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      case 'resolved':
        return Colors.blue;
      case 'closed':
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

  // ── Build ─────────────────────────────────────────────────────────────────
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
          // ── Search + status filter bar ──────────────────────────────
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
                // Search field
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

                // ── Status filter — 100% from API, zero hardcoded ─────
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
                            });
                            _handleSearch();
                          }
                        },
                        items: [
                          // "All" is the only fixed option
                          const DropdownMenuItem(
                            value: 'All',
                            child: Text('All'),
                          ),
                          // Rest come entirely from the API
                          ..._statusFilters.map(
                            (s) => DropdownMenuItem(
                              value: s['value'], // e.g. "in_progress"
                              child: Text(s['label']!), // e.g. "In Progress"
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Ticket table ────────────────────────────────────────────
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

// ── Ticket Details Screen ─────────────────────────────────────────────────────

class TicketDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final List<Map<String, dynamic>> subscriptions;

  const TicketDetailsScreen({
    super.key,
    required this.ticket,
    required this.subscriptions,
  });

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
      case 'RESOLVED':
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

  Future<void> _downloadAttachment(String? fileId) async {
    if (fileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download not available for this file'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    try {
      final response = await ApiService.downloadAttachment(fileId);
      if (response['status'] == 'success') {
        final fileName = response['filename']?.toString().trim();
        final base64Str = response['base64']?.toString().trim();
        if (fileName == null ||
            fileName.isEmpty ||
            base64Str == null ||
            base64Str.isEmpty) {
          throw Exception('Server returned invalid attachment data.');
        }
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(base64Decode(base64Str));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File downloaded to: ${file.path}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception(
          response['message']?.toString() ?? 'Failed to download file',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading file: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('TicketDetailsScreen _ticket: $_ticket');
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
                      _buildDetailItem(
                        'Contact',
                        _ticket['full_data']?['contact_name']?.toString() ??
                            'Not Assigned',
                      ),
                      const SizedBox(height: 16),
                      _buildDetailItem(
                        'Subscription',
                        getNickname(
                          _subscriptions,
                          _ticket['subscription']?.toString(),
                        ),
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
            if (attachments != null &&
                attachments.toString().isNotEmpty &&
                attachments.toString() != '[]') ...[
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
                      ...(attachments).map((attachment) {
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
                                onPressed: () => _downloadAttachment(fileId),
                                tooltip: 'Download file',
                              ),
                            ],
                          ),
                        );
                      }),
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
