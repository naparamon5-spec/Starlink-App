import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../../services/api_service.dart';
import '../../../utils/file_download/file_downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Design tokens — MATCHING home screen exactly ──────────────────────────────
const _brandRed = Color(0xFFEB1E23);
const _inProgress = Color(0xFF0F62FE);
const _success = Color(0xFF24A148); // matches home _success
const _warning = Color(0xFFFF832B); // matches home _warning (orange)
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF374151);
const _inkTertiary = Color(0xFF8A96A3);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF5F7FA);
const _border = Color(0xFFE8ECF0);

class CustomerViewScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const CustomerViewScreen({super.key, required this.ticket});

  @override
  _CustomerViewScreenState createState() => _CustomerViewScreenState();
}

class _CustomerViewScreenState extends State<CustomerViewScreen> {
  bool _isActionLoading = false;

  Map<String, dynamic>? _fetchedTicket;
  bool _isFetchingDetails = true;
  String? _fetchError;

  List<dynamic> _attachments = [];
  String? _attachmentsError;
  final Map<String, bool> _downloadingMap = {};

  @override
  void initState() {
    super.initState();
    _loadTicketDetails();
  }

  Future<void> _loadTicketDetails() async {
    if (!mounted) return;
    setState(() {
      _isFetchingDetails = true;
      _fetchError = null;
      _attachments = [];
      _attachmentsError = null;
    });
    try {
      final ticketId =
          widget.ticket['id']?.toString() ??
          widget.ticket['full_data']?['id']?.toString() ??
          '';
      if (ticketId.isEmpty) {
        setState(() {
          _isFetchingDetails = false;
          _fetchError = 'Ticket ID not found.';
        });
        return;
      }

      final results = await Future.wait([
        ApiService.getTicketById(ticketId),
        ApiService.getTicketAttachments(ticketId),
      ]);
      if (!mounted) return;

      Map<String, dynamic>? ticket;
      String? ticketError;
      final ticketRes = results[0];
      if (ticketRes['status'] == 'success') {
        final d = ticketRes['data'];
        ticket = d is Map ? Map<String, dynamic>.from(d) : null;
      } else {
        ticketError =
            ticketRes['message']?.toString() ??
            'Failed to load ticket details.';
      }

      List<dynamic> attachments = [];
      String? attachmentsErr;
      final attRes = results[1];
      if (attRes['status'] == 'success') {
        attachments = _extractList(attRes['data']);
        if (attachments.isEmpty) attachments = _extractList(attRes['raw']);
      } else {
        attachmentsErr =
            attRes['message']?.toString() ?? 'Failed to load attachments.';
      }

      setState(() {
        _fetchedTicket = ticket;
        _fetchError = ticketError;
        _attachments = attachments;
        _attachmentsError = attachmentsErr;
        _isFetchingDetails = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchError = 'Error loading ticket: $e';
        _isFetchingDetails = false;
      });
    }
  }

  // ── Status helpers ────────────────────────────────────────────────────────

  String get _currentStatus {
    final raw =
        _fetchedTicket?['status']?.toString() ??
        widget.ticket['full_data']?['status']?.toString() ??
        widget.ticket['status']?.toString() ??
        'OPEN';
    return _normalizeStatus(raw);
  }

  String _normalizeStatus(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'open':
      case 'opened':
        return 'OPEN';
      case 'in_progress':
      case 'in progress':
      case 'inprogress':
        return 'IN PROGRESS';
      case 'resolved':
      case 'done':
      case 'completed':
        return 'RESOLVED';
      case 'closed':
      case 'close':
        return 'CLOSED';
      default:
        return raw.toUpperCase();
    }
  }

  void _updateLocalStatus(String newStatus) {
    setState(() {
      widget.ticket['status'] = newStatus;
      if (widget.ticket['full_data'] != null) {
        widget.ticket['full_data']['status'] = newStatus;
      }
      if (_fetchedTicket != null) _fetchedTicket!['status'] = newStatus;
    });
  }

  // ── Status color — aligned with home screen tokens ────────────────────────
  Color _statusColor(String s) {
    switch (s.toUpperCase()) {
      case 'OPEN':
        return _warning; // orange  0xFFFF832B ✓
      case 'IN PROGRESS':
        return _inProgress; // blue    0xFF0F62FE ✓
      case 'RESOLVED':
        return _success; // green   0xFF24A148 ✓
      case 'CLOSED':
        return const Color(0xFFA8A8A8); // grey ✓
      default:
        return const Color(0xFF94A3B8);
    }
  }

  // ── Timeline helpers ──────────────────────────────────────────────────────

  IconData _activityIcon(String? action) {
    final v = (action ?? '').toLowerCase();
    if (v.contains('creat')) return Icons.add_circle_outline_rounded;
    if (v.contains('updat') || v.contains('edit')) return Icons.edit_outlined;
    if (v.contains('resolv')) return Icons.check_circle_outline_rounded;
    if (v.contains('close') || v.contains('clos')) return Icons.cancel_outlined;
    if (v.contains('comment') || v.contains('note')) {
      return Icons.comment_outlined;
    }
    if (v.contains('assign')) return Icons.person_add_alt_outlined;
    if (v.contains('status') || v.contains('chang')) {
      return Icons.swap_horiz_rounded;
    }
    return Icons.history_toggle_off_outlined;
  }

  Color _activityColor(String? action) {
    final v = (action ?? '').toLowerCase();
    if (v.contains('creat')) return _success;
    if (v.contains('resolv')) return _success;
    if (v.contains('close')) return _warning;
    if (v.contains('comment') || v.contains('note')) {
      return const Color(0xFF6366F1);
    }
    if (v.contains('assign')) return _brandRed;
    if (v.contains('status') || v.contains('chang')) return _inProgress;
    return const Color(0xFF94A3B8);
  }

  String _timeAgo(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return _formatDate(raw);
    } catch (_) {
      return '';
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$m $period';
    } catch (_) {
      return raw;
    }
  }

  String _str(dynamic v, {String fallback = '—'}) {
    if (v == null || v.toString() == 'null' || v.toString().isEmpty) {
      return fallback;
    }
    return v.toString();
  }

  String _resolveValue(List<String?> candidates, {String fallback = 'N/A'}) {
    for (final v in candidates) {
      if (v != null && v.isNotEmpty && v != 'null') return v;
    }
    return fallback;
  }

  String _prettifyValue(String v) {
    switch (v.toLowerCase()) {
      case 'in_progress':
        return 'In Progress';
      case 'open':
        return 'Open';
      case 'closed':
        return 'Closed';
      case 'resolved':
        return 'Resolved';
      default:
        return v.isNotEmpty ? v[0].toUpperCase() + v.substring(1) : v;
    }
  }

  List<dynamic> _extractList(dynamic d) {
    if (d is List) return d;
    if (d is Map) {
      for (final key in [
        'data',
        'attachments',
        'items',
        'records',
        'results',
        'list',
      ]) {
        final v = d[key];
        if (v is List) return v;
        if (v is Map) {
          final inner = _extractList(v);
          if (inner.isNotEmpty) return inner;
        }
      }
    }
    return [];
  }

  Color _extColor(String ext) {
    switch (ext) {
      case 'pdf':
        return _brandRed;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
        return _success;
      case 'doc':
      case 'docx':
        return _inProgress;
      case 'xls':
      case 'xlsx':
        return _success;
      case 'zip':
      case 'rar':
        return _warning;
      default:
        return const Color(0xFF6366F1);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  //
  // NOTE: Accept / Resolve / Close are ADMIN actions.
  // Customers can only VIEW their tickets — the action bar is intentionally
  // hidden for all customer-created tickets (see build() below).
  // These methods are kept in case a future role distinction is needed.

  Future<void> _acceptTicket() async {
    setState(() => _isActionLoading = true);
    try {
      final response = await ApiService.updateTicketStatus(
        widget.ticket['id'].toString(),
        'in_progress',
      );
      if (response['status'] == 'success') {
        _updateLocalStatus('IN PROGRESS');
        await _setTicketInProgress(widget.ticket['id'].toString());
        await _saveInProgressTicketData(widget.ticket);
        if (mounted) {
          _showSnack('Ticket accepted successfully');
          Navigator.pop(context, {
            'status': 'IN PROGRESS',
            'id': widget.ticket['id'].toString(),
          });
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to accept ticket');
      }
    } catch (e) {
      if (mounted) _showSnack('Error accepting ticket: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _resolveTicket() async {
    setState(() => _isActionLoading = true);
    try {
      final response = await ApiService.updateTicketStatus(
        widget.ticket['id'].toString(),
        'resolved',
      );
      if (response['status'] == 'success') {
        _updateLocalStatus('RESOLVED');
        await _removeTicketInProgress(widget.ticket['id'].toString());
        if (mounted) {
          _showSnack('Ticket resolved successfully');
          Navigator.pop(context, {
            'status': 'RESOLVED',
            'id': widget.ticket['id'].toString(),
          });
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to resolve ticket');
      }
    } catch (e) {
      if (mounted) _showSnack('Error resolving ticket: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _closeTicket() async {
    setState(() => _isActionLoading = true);
    try {
      final response = await ApiService.updateTicketStatus(
        widget.ticket['id'].toString(),
        'closed',
      );
      if (response['status'] == 'success') {
        _updateLocalStatus('CLOSED');
        await _removeTicketInProgress(widget.ticket['id'].toString());
        if (mounted) {
          _showSnack('Ticket closed successfully');
          Navigator.pop(context, {
            'status': 'CLOSED',
            'id': widget.ticket['id'].toString(),
          });
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to close ticket');
      }
    } catch (e) {
      if (mounted) _showSnack('Error closing ticket: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? _brandRed : _success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── SharedPreferences helpers ─────────────────────────────────────────────

  Future<void> _saveInProgressTicketIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('in_progress_ticket_ids', ids);
  }

  Future<List<String>> _getInProgressTicketIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('in_progress_ticket_ids') ?? [];
  }

  Future<void> _setTicketInProgress(String ticketId) async {
    final ids = await _getInProgressTicketIds();
    if (!ids.contains(ticketId)) {
      ids.add(ticketId);
      await _saveInProgressTicketIds(ids);
    }
  }

  Future<void> _removeTicketInProgress(String ticketId) async {
    final ids = await _getInProgressTicketIds();
    ids.remove(ticketId);
    await _saveInProgressTicketIds(ids);
  }

  Future<void> _saveInProgressTicketData(Map<String, dynamic> ticket) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList('in_progress_tickets_data') ?? [];
    rawList.removeWhere((item) {
      final data = jsonDecode(item);
      return data['id'].toString() == ticket['id'].toString();
    });
    rawList.add(jsonEncode(ticket));
    await prefs.setStringList('in_progress_tickets_data', rawList);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final passedFull =
        (widget.ticket['full_data'] as Map<String, dynamic>?) ?? widget.ticket;
    final data = _fetchedTicket ?? passedFull;

    final status = _currentStatus;
    final statusColor = _statusColor(status);

    final String ticketId = _str(data['id'] ?? widget.ticket['id']);
    final String subject = _resolveValue([
      data['subject']?.toString(),
      passedFull['subject']?.toString(),
      widget.ticket['Subscription']?.toString(),
    ], fallback: 'Ticket #$ticketId');

    final String ticketType = _resolveValue([
      data['ticket_type']?.toString(),
      data['type']?.toString(),
      widget.ticket['Ticket Type']?.toString(),
    ]);

    final String contact = _resolveValue([
      data['contact_name']?.toString(),
      data['created_by']?.toString(),
      data['requester']?.toString(),
      widget.ticket['Contact']?.toString(),
    ]);

    final String createdAt = _resolveValue([
      data['created_at']?.toString(),
      passedFull['created_at']?.toString(),
      widget.ticket['Created At']?.toString(),
    ]);

    final String description = _resolveValue([
      data['description']?.toString(),
      passedFull['description']?.toString(),
      widget.ticket['Description']?.toString(),
    ], fallback: 'No description provided.');

    final dynamic rawTimeline = data['timeline'];
    final List<dynamic> timeline = rawTimeline is List ? rawTimeline : [];

    final dynamic rawAttachments =
        data['attachments'] ?? passedFull['attachments'];
    final List attachments =
        _attachments.isNotEmpty
            ? _attachments
            : (rawAttachments is List ? rawAttachments : []);

    // ── Determine if action bar should be shown ───────────────────────────
    // Customers create tickets and should NOT be able to accept/resolve/close
    // their own tickets — those are admin-only actions.
    // We detect "customer-created" by checking the role stored in SharedPrefs.
    // Since this screen is always in the customer flow, we simply hide the bar.
    const bool isCustomerView = true; // always true in this screen

    return Scaffold(
      backgroundColor: _surfaceSubtle,
      appBar: AppBar(
        backgroundColor: _surface,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            Text(
              'Ticket #$ticketId',
              style: const TextStyle(fontSize: 11, color: _inkTertiary),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _brandRed, size: 20),
            onPressed: _isFetchingDetails ? null : _loadTicketDetails,
            tooltip: 'Refresh',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTicketDetails,
        color: _brandRed,
        // ── No Stack/Positioned needed — no action bar for customers ──────
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // ── Ticket Info Card ──────────────────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject + status badge
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Subject',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _inkTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subject,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _StatusBadge(label: status, color: statusColor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _HDivider(),

                  // Type chip
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _InfoChip(
                      icon: Icons.label_outline_rounded,
                      label: 'Type',
                      value: ticketType,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _HDivider(),

                  // Description
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 11,
                            color: _inkTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            description,
                            style: const TextStyle(
                              fontSize: 13,
                              color: _inkSecondary,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _HDivider(),

                  // KV rows
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      children: [
                        _KVRow(label: 'Contact', value: contact),
                        const SizedBox(height: 8),
                        _KVRow(
                          label: 'Created At',
                          value: _formatDate(createdAt),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Attachments Card ──────────────────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _warning.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.attach_file_rounded,
                            color: _warning,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Attachments',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const Spacer(),
                        if (attachments.isNotEmpty)
                          _CountBadge(
                            count: attachments.length,
                            color: _warning,
                          ),
                      ],
                    ),
                  ),
                  const _HDivider(),
                  if (attachments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: _inkTertiary,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'No attachments',
                            style: TextStyle(color: _inkTertiary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      itemCount: attachments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final att = attachments[i];
                        if (att is! Map) return const SizedBox.shrink();
                        final name = _str(
                          att['name'] ?? att['filename'] ?? att['file_name'],
                          fallback: 'Unknown file',
                        );
                        final ext =
                            name.contains('.')
                                ? name.split('.').last.toLowerCase()
                                : '';
                        final size = _str(
                          att['size'] ?? att['file_size'],
                          fallback: '',
                        );
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _extColor(ext).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    ext.isNotEmpty
                                        ? ext.toUpperCase().substring(
                                          0,
                                          ext.length > 4 ? 4 : ext.length,
                                        )
                                        : 'FILE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: _extColor(ext),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: _ink,
                                      ),
                                    ),
                                    if (size.isNotEmpty)
                                      Text(
                                        size,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: _inkTertiary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Builder(
                                builder: (_) {
                                  final attId =
                                      att['id']?.toString() ??
                                      att['attachment_id']?.toString() ??
                                      att['attachmentId']?.toString() ??
                                      '';
                                  final isDownloading =
                                      attId.isNotEmpty &&
                                      _downloadingMap[attId] == true;
                                  if (isDownloading) {
                                    return const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _inkTertiary,
                                      ),
                                    );
                                  }
                                  return IconButton(
                                    icon: const Icon(
                                      Icons.download_outlined,
                                      color: _inkTertiary,
                                      size: 20,
                                    ),
                                    onPressed: () => _downloadAttachment(att),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Activity Timeline Card ────────────────────────────────────
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _brandRed.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.timeline_rounded,
                            color: _brandRed,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Activity Timeline',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                        const Spacer(),
                        if (_isFetchingDetails)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _brandRed,
                            ),
                          )
                        else if (timeline.isNotEmpty)
                          _CountBadge(count: timeline.length, color: _brandRed),
                      ],
                    ),
                  ),
                  const _HDivider(),

                  if (_isFetchingDetails)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _brandRed,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Loading timeline…',
                              style: TextStyle(
                                fontSize: 12,
                                color: _inkTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_fetchError != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _brandRed.withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: _brandRed,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _fetchError!,
                                style: const TextStyle(
                                  color: _brandRed,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (timeline.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: _inkTertiary,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'No activity yet',
                            style: TextStyle(color: _inkTertiary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        children: List.generate(timeline.length, (i) {
                          final act = timeline[i];
                          if (act is! Map) return const SizedBox.shrink();
                          final action = _str(
                            act['action'],
                            fallback: 'Activity',
                          );
                          final userName = _str(
                            act['user_name'] ?? act['performed_by'],
                            fallback: '',
                          );
                          final oldVal = act['old_value']?.toString();
                          final newVal = act['new_value']?.toString();
                          final timestamp = act['created_at']?.toString();
                          String? changeDesc;
                          if (oldVal != null &&
                              newVal != null &&
                              oldVal != 'null' &&
                              newVal != 'null') {
                            changeDesc =
                                '${_prettifyValue(oldVal)}  →  ${_prettifyValue(newVal)}';
                          }
                          final color = _activityColor(action);
                          final icon = _activityIcon(action);
                          final isLast = i == timeline.length - 1;
                          return _TimelineRow(
                            icon: icon,
                            color: color,
                            isLast: isLast,
                            action: action,
                            changeDesc: changeDesc,
                            performedBy:
                                (userName.isNotEmpty && userName != '—')
                                    ? userName
                                    : null,
                            formattedDate:
                                timestamp != null
                                    ? _formatDate(timestamp)
                                    : null,
                            timeAgo: _timeAgo(timestamp),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),

            // ── Status info pill (read-only, replaces action buttons) ─────
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _statusIcon(status),
                      color: statusColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Status',
                          style: TextStyle(
                            fontSize: 11,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _statusDescription(status),
                          style: const TextStyle(
                            fontSize: 12,
                            color: _inkSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(label: status, color: statusColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'OPEN':
        return Icons.error_outline;
      case 'IN PROGRESS':
        return Icons.sync;
      case 'RESOLVED':
        return Icons.check_circle_outline;
      case 'CLOSED':
        return Icons.lock_outline;
      default:
        return Icons.help_outline;
    }
  }

  String _statusDescription(String status) {
    switch (status) {
      case 'OPEN':
        return 'Your ticket is awaiting review by our support team.';
      case 'IN PROGRESS':
        return 'Our support team is currently working on your ticket.';
      case 'RESOLVED':
        return 'Your ticket has been resolved. Thank you for your patience.';
      case 'CLOSED':
        return 'This ticket has been closed.';
      default:
        return 'Status: $status';
    }
  }

  Future<void> _downloadAttachment(dynamic att) async {
    final attachmentId =
        att is Map
            ? _str(
              att['id'] ?? att['attachment_id'] ?? att['attachmentId'],
              fallback: '—',
            )
            : '—';

    if (attachmentId == '—' || attachmentId.isEmpty) {
      _showSnack('Cannot download: attachment ID is missing.', isError: true);
      return;
    }

    setState(() => _downloadingMap[attachmentId] = true);

    try {
      final result = await ApiService.downloadAttachment(attachmentId);

      if (!mounted) return;

      if (result['status'] != 'success') {
        _showSnack(
          result['message']?.toString() ?? 'Download failed.',
          isError: true,
        );
        return;
      }

      final filename =
          result['filename']?.toString().trim().isNotEmpty == true
              ? result['filename'].toString().trim()
              : _attFilename(att);

      final base64Str = result['base64']?.toString() ?? '';

      if (base64Str.isEmpty) {
        _showSnack('Download failed: empty file data.', isError: true);
        return;
      }

      Uint8List bytes;
      try {
        bytes = base64Decode(base64Str);
      } catch (e) {
        _showSnack('Download failed: invalid file data.', isError: true);
        return;
      }

      final mimeType = _resolveMimeType(
        apiMime: result['mimeType']?.toString(),
        filename: filename,
        bytes: bytes,
      );

      final savedPath = await saveBytesAsFile(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
      );

      if (!mounted) return;

      if (savedPath != null && savedPath.isNotEmpty) {
        _showSnack('Saved to: $savedPath');
      } else {
        _showSnack('Downloaded: $filename');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Download error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _downloadingMap.remove(attachmentId));
    }
  }

  String _attFilename(dynamic att) {
    if (att is Map) {
      final f =
          att['name'] ?? att['filename'] ?? att['file_name'] ?? att['fileName'];
      if (f is String && f.trim().isNotEmpty) return f.trim();
    }
    return 'attachment';
  }

  String _resolveMimeType({
    required String? apiMime,
    required String filename,
    required Uint8List bytes,
  }) {
    final trimmed = apiMime?.trim() ?? '';
    if (trimmed.isNotEmpty &&
        trimmed != 'application/octet-stream' &&
        trimmed.contains('/')) {
      return trimmed;
    }
    final byExt = _mimeFromFilename(filename);
    if (byExt != null) return byExt;
    final byMagic = _mimeFromMagic(bytes);
    if (byMagic != null) return byMagic;
    return trimmed.isNotEmpty ? trimmed : 'application/octet-stream';
  }

  String? _mimeFromFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.rar')) return 'application/x-rar-compressed';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.xml')) return 'application/xml';
    return null;
  }

  String? _mimeFromMagic(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return 'image/gif';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return 'application/pdf';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      return 'application/zip';
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline Row widget
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isLast;
  final String action;
  final String? changeDesc;
  final String? performedBy;
  final String? formattedDate;
  final String timeAgo;

  const _TimelineRow({
    required this.icon,
    required this.color,
    required this.isLast,
    required this.action,
    required this.timeAgo,
    this.changeDesc,
    this.performedBy,
    this.formattedDate,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withOpacity(0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(icon, color: color, size: 15),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          action,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      if (timeAgo.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          timeAgo,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF8A96A3),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (changeDesc != null && changeDesc!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withOpacity(0.2)),
                      ),
                      child: Text(
                        changeDesc!,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                  if (performedBy != null && performedBy!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 12,
                          color: Color(0xFF8A96A3),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            performedBy!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8A96A3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (formattedDate != null && formattedDate!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      formattedDate!,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFFB0BAC9),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE8ECF0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class _HDivider extends StatelessWidget {
  const _HDivider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: const Color(0xFFF0F4F8));
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.4), width: 1.2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.4,
          ),
        ),
      ],
    ),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _KVRow extends StatelessWidget {
  final String label;
  final String value;
  const _KVRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 110,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: _inkTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: _ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _CountBadge({required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$count',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
    ),
  );
}
