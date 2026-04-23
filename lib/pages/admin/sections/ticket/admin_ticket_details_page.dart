import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../services/api_service.dart';
import '../../../../utils/file_download/file_downloader.dart';

class AdminTicketDetailsPage extends StatefulWidget {
  final String ticketId;
  final String? subject;

  const AdminTicketDetailsPage({
    super.key,
    required this.ticketId,
    this.subject,
  });

  @override
  State<AdminTicketDetailsPage> createState() => _AdminTicketDetailsPageState();
}

class _AdminTicketDetailsPageState extends State<AdminTicketDetailsPage> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _ticket;
  List<dynamic> _activities = [];
  List<dynamic> _attachments = [];

  String? _ticketError;
  String? _activitiesError;
  String? _attachmentsError;

  final Map<String, bool> _downloadingMap = {};

  static const _brandRed = Color(0xFFEB1E23);
  static const _brandDark = Color(0xFF760F12);

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  String _str(dynamic v) =>
      (v == null || v.toString() == 'null' || v.toString().isEmpty)
          ? '—'
          : v.toString();

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return '—';
    try {
      final dt = DateTime.parse(raw);
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

  // ── Robust list extraction ─────────────────────────────────────────────────

  List<dynamic> _extractList(dynamic d) {
    if (d is List) return d;
    if (d is Map) {
      for (final key in [
        'data',
        'activities',
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

  // ── load ───────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _ticketError = null;
      _activitiesError = null;
      _attachmentsError = null;
      _ticket = null;
      _activities = [];
      _attachments = [];
    });

    final id = widget.ticketId.trim();

    final results = await Future.wait([
      ApiService.getTicketById(id),
      ApiService.getTicketActivities(id),
      ApiService.getTicketAttachments(id),
    ]);

    if (!mounted) return;

    // ── 1. Ticket
    Map<String, dynamic>? ticket;
    String? ticketErr;
    final ticketRes = results[0];
    if (ticketRes['status'] == 'success') {
      final d = ticketRes['data'];
      ticket = d is Map ? Map<String, dynamic>.from(d) : null;
    } else {
      ticketErr = ticketRes['message']?.toString() ?? 'Failed to load ticket';
    }

    // ── 2. Activities (from dedicated endpoint)
    List<dynamic> activities = [];
    String? activitiesErr;
    final actRes = results[1];
    if (actRes['status'] == 'success') {
      activities = _extractList(actRes['data']);
      if (activities.isEmpty) activities = _extractList(actRes['raw']);
    } else {
      activitiesErr =
          actRes['message']?.toString() ?? 'Failed to load activities';
    }

    // ── Also extract 'timeline' embedded directly in the ticket response
    // (e.g. ticket['timeline'] from GET /api/v1/tickets/:id)
    if (ticket != null) {
      final embedded = ticket['timeline'];
      if (embedded is List && embedded.isNotEmpty) {
        final existingIds =
            activities
                .whereType<Map>()
                .map((a) => a['id']?.toString())
                .whereType<String>()
                .toSet();
        for (final item in embedded) {
          final itemId = (item is Map) ? item['id']?.toString() : null;
          if (itemId == null || !existingIds.contains(itemId)) {
            activities.add(item);
          }
        }
        // We have activity data, so clear any fetch error
        activitiesErr = null;
      }
    }

    // ── 3. Attachments
    List<dynamic> attachments = [];
    String? attachmentsErr;
    final attRes = results[2];
    if (attRes['status'] == 'success') {
      attachments = _extractList(attRes['data']);
      if (attachments.isEmpty) attachments = _extractList(attRes['raw']);
    } else {
      attachmentsErr =
          attRes['message']?.toString() ?? 'Failed to load attachments';
    }

    setState(() {
      _ticket = ticket;
      _ticketError = ticketErr;
      _activities = activities;
      _activitiesError = activitiesErr;
      _attachments = attachments;
      _attachmentsError = attachmentsErr;
      _loading = false;

      if (ticket == null && activities.isEmpty && attachments.isEmpty) {
        _error = 'Failed to load ticket data.';
      }
    });
  }

  // ── download ───────────────────────────────────────────────────────────────

  Future<void> _downloadAttachment(dynamic att) async {
    final attachmentId =
        att is Map
            ? _str(att['id'] ?? att['attachment_id'] ?? att['attachmentId'])
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

      final rawFilename =
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
        bytes = _decodeBase64Data(base64Str);
      } catch (e) {
        _showSnack('Download failed: invalid file data.', isError: true);
        return;
      }

      final mimeType = _resolveMimeType(
        apiMime: result['mimeType']?.toString(),
        filename: rawFilename,
        bytes: bytes,
      );

      final filename = _ensureFilenameHasExtension(
        rawFilename,
        mimeType: mimeType,
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

  Uint8List _decodeBase64Data(String raw) {
    var normalized = raw.trim();

    final dataUriIndex = normalized.indexOf(',');
    if (normalized.toLowerCase().contains('base64,') && dataUriIndex != -1) {
      normalized = normalized.substring(dataUriIndex + 1);
    }

    normalized = normalized.replaceAll(RegExp(r'\s+'), '');
    normalized = normalized.replaceAll('-', '+').replaceAll('_', '/');

    final remainder = normalized.length % 4;
    if (remainder != 0) {
      normalized = normalized.padRight(
        normalized.length + (4 - remainder),
        '=',
      );
    }

    return base64Decode(normalized);
  }

  String _ensureFilenameHasExtension(
    String filename, {
    required String mimeType,
    required Uint8List bytes,
  }) {
    final clean = filename.trim().isEmpty ? 'attachment' : filename.trim();
    final hasExtension = clean.contains('.') && !clean.endsWith('.');

    if (hasExtension) return clean;

    final ext = _extensionFromMimeOrBytes(mimeType, bytes);
    if (ext == null || ext.isEmpty) return clean;

    return '$clean.$ext';
  }

  String? _extensionFromMimeOrBytes(String mimeType, Uint8List bytes) {
    final normalized = mimeType.toLowerCase().trim();

    switch (normalized) {
      case 'image/jpeg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/gif':
        return 'gif';
      case 'image/webp':
        return 'webp';
      case 'application/pdf':
        return 'pdf';
      case 'application/msword':
        return 'doc';
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return 'docx';
      case 'application/vnd.ms-excel':
        return 'xls';
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return 'xlsx';
      case 'application/vnd.ms-powerpoint':
        return 'ppt';
      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        return 'pptx';
      case 'text/plain':
        return 'txt';
      case 'text/csv':
        return 'csv';
      case 'application/json':
        return 'json';
      case 'application/xml':
      case 'text/xml':
        return 'xml';
      case 'application/zip':
        return 'zip';
      case 'application/x-rar-compressed':
        return 'rar';
      case 'video/mp4':
        return 'mp4';
      case 'audio/mpeg':
        return 'mp3';
    }

    final magicMime = _mimeFromMagic(bytes);
    if (magicMime != null && magicMime != mimeType) {
      return _extensionFromMimeOrBytes(magicMime, bytes);
    }

    return null;
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
      if (bytes.length >= 4 + 26) {
        final compressedSize =
            bytes[18] |
            (bytes[19] << 8) |
            (bytes[20] << 16) |
            (bytes[21] << 24);
        final uncompressedSize =
            bytes[22] |
            (bytes[23] << 8) |
            (bytes[24] << 16) |
            (bytes[25] << 24);
        final fileNameLength = bytes[26] | (bytes[27] << 8);

        if (bytes.length >= 30 + fileNameLength) {
          try {
            final entryNameBytes = bytes.sublist(30, 30 + fileNameLength);
            final entryName =
                utf8.decode(entryNameBytes, allowMalformed: true).toLowerCase();

            if (entryName == '[content_types].xml') {
              return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
            }
            if (entryName.contains('word/')) {
              return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
            }
            if (entryName.contains('xl/')) {
              return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
            }
            if (entryName.contains('ppt/')) {
              return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
            }
          } catch (_) {}
        }

        if (compressedSize == 0 && uncompressedSize == 0) {
          return 'application/zip';
        }
      }
      return 'application/zip';
    }
    return null;
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _brandRed : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── status / priority / activity helpers ───────────────────────────────────

  Color _statusColor(String s) {
    final v = s.toLowerCase();
    if (v.contains('open')) return const Color(0xFF64748B);
    if (v.contains('progress')) return const Color(0xFF0F62FE);
    if (v.contains('resolved')) return const Color(0xFF10B981);
    if (v.contains('closed')) return const Color(0xFFF59E0B);
    return const Color(0xFF94A3B8);
  }

  Color _priorityColor(String p) {
    final v = p.toLowerCase();
    if (v.contains('high') || v.contains('urgent')) {
      return const Color(0xFFEB1E23);
    }
    if (v.contains('medium') || v.contains('normal')) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF10B981);
  }

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
    if (v.contains('open')) return Icons.folder_open_outlined;
    return Icons.history_toggle_off_outlined;
  }

  Color _activityColor(String? action) {
    final v = (action ?? '').toLowerCase();
    if (v.contains('creat')) return const Color(0xFF10B981);
    if (v.contains('resolv')) return const Color(0xFF10B981);
    if (v.contains('close')) return const Color(0xFFF59E0B);
    if (v.contains('comment') || v.contains('note')) {
      return const Color(0xFF6366F1);
    }
    if (v.contains('assign')) return _brandRed;
    return const Color(0xFF94A3B8);
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appBarTitle =
        widget.subject?.isNotEmpty == true
            ? widget.subject!
            : 'Ticket #${widget.ticketId}';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF000000),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appBarTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF000000),
              ),
            ),
            Text(
              'Ticket #${widget.ticketId}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8A96A3)),
            ),
          ],
        ),
        // actions: [
        //   IconButton(
        //     icon: Icon(Icons.refresh_rounded, color: _brandRed),
        //     onPressed: _loading ? null : _load,
        //   ),
        // ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE8ECF0)),
        ),
      ),
      body:
          _loading
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: _brandRed,
                      strokeWidth: 2.5,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Loading ticket…',
                      style: TextStyle(color: Color(0xFF8A96A3), fontSize: 13),
                    ),
                  ],
                ),
              )
              : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                onRefresh: _load,
                color: _brandRed,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  children: [
                    if (_ticketError != null)
                      _ErrorCard(message: _ticketError!)
                    else
                      _buildTicketCard(),
                    const SizedBox(height: 14),
                    _buildAttachmentsCard(),
                    const SizedBox(height: 14),
                    _buildActivitiesCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _brandRed.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: _brandRed,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF000000),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brandRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ticket Card ────────────────────────────────────────────────────────────

  Widget _buildTicketCard() {
    final t = _ticket;
    if (t == null) return const SizedBox.shrink();

    final status = _str(t['status'] ?? t['ticket_status']);
    final priority = _str(t['priority']);
    final ticketType = _str(t['ticket_type'] ?? t['type'] ?? t['category']);
    final description = _str(t['description'] ?? t['body'] ?? t['content']);
    final createdBy = _str(t['created_by'] ?? t['createdBy'] ?? t['creator']);
    final assignedTo = _str(t['assigned_to'] ?? t['assignedTo'] ?? t['agent']);
    final contact = _str(t['contact'] ?? t['contact_name']);
    final subscription = _str(
      t['subscription_id'] ?? t['subscription'] ?? t['serviceLineNumber'],
    );
    final createdAt = _formatDate(
      t['created_at']?.toString() ?? t['createdAt']?.toString(),
    );
    final updatedAt = _formatDate(
      t['updated_at']?.toString() ?? t['updatedAt']?.toString(),
    );
    final subject = _str(t['subject'] ?? t['title']);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                          color: Color(0xFF8A96A3),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subject,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF000000),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _StatusBadge(label: status, color: _statusColor(status)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _HDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    icon: Icons.label_outline_rounded,
                    label: 'Type',
                    value: ticketType,
                    color: const Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 10),
                if (priority != '—')
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.flag_outlined,
                      label: 'Priority',
                      value: priority,
                      color: _priorityColor(priority),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _HDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A96A3),
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
                      color: Color(0xFF374151),
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _HDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                _KVRow(label: 'Created By', value: createdBy),
                const SizedBox(height: 8),
                _KVRow(label: 'Assigned To', value: assignedTo),
                const SizedBox(height: 8),
                _KVRow(label: 'Contact', value: contact),
                const SizedBox(height: 8),
                _KVRow(label: 'Subscription', value: subscription),
                const SizedBox(height: 8),
                _KVRow(label: 'Created At', value: createdAt),
                const SizedBox(height: 8),
                _KVRow(label: 'Last Updated', value: updatedAt),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Attachments Card ───────────────────────────────────────────────────────

  Widget _buildAttachmentsCard() {
    return _Card(
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
                    color: const Color(0xFFF59E0B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.attach_file_rounded,
                    color: Color(0xFFF59E0B),
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Attachments',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF000000),
                  ),
                ),
                const Spacer(),
                if (_attachments.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_attachments.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const _HDivider(),
          if (_attachmentsError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _ErrorCard(message: _attachmentsError!),
            )
          else if (_attachments.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF8A96A3),
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'No attachments',
                    style: TextStyle(color: Color(0xFF8A96A3), fontSize: 13),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              itemCount: _attachments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final att = _attachments[i];
                final attachmentId =
                    att is Map
                        ? _str(
                          att['id'] ??
                              att['attachment_id'] ??
                              att['attachmentId'],
                        )
                        : '—';
                final name = _str(
                  att is Map
                      ? (att['name'] ?? att['filename'] ?? att['file_name'])
                      : att,
                );
                final size =
                    att is Map ? _str(att['size'] ?? att['file_size']) : '—';
                final type =
                    att is Map
                        ? _str(
                          att['type'] ?? att['mime_type'] ?? att['file_type'],
                        )
                        : '—';
                final ext =
                    name.contains('.')
                        ? name.split('.').last.toLowerCase()
                        : '';
                final isDownloading = _downloadingMap[attachmentId] == true;

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
                                color: Color(0xFF000000),
                              ),
                            ),
                            if (size != '—' || type != '—')
                              Text(
                                [
                                  if (type != '—') type,
                                  if (size != '—') size,
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8A96A3),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _AttachmentDownloadButton(
                        isDownloading: isDownloading,
                        hasId: attachmentId != '—',
                        brandRed: _brandRed,
                        onTap: () => _downloadAttachment(att),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Color _extColor(String ext) {
    switch (ext) {
      case 'pdf':
        return const Color(0xFFEB1E23);
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
        return const Color(0xFF10B981);
      case 'doc':
      case 'docx':
        return const Color(0xFF0F62FE);
      case 'xls':
      case 'xlsx':
        return const Color(0xFF10B981);
      case 'zip':
      case 'rar':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6366F1);
    }
  }

  // ── Activities Card ────────────────────────────────────────────────────────

  Widget _buildActivitiesCard() {
    return _Card(
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
                  child: Icon(
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
                    color: Color(0xFF000000),
                  ),
                ),
                const Spacer(),
                if (_activities.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _brandRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_activities.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _brandRed,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const _HDivider(),
          if (_activitiesError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _ErrorCard(message: _activitiesError!),
            )
          else if (_activities.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF8A96A3),
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'No activity yet',
                    style: TextStyle(color: Color(0xFF8A96A3), fontSize: 13),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: List.generate(_activities.length, (i) {
                  final act = _activities[i];
                  final isLast = i == _activities.length - 1;

                  String field(List<String> keys) {
                    if (act is! Map) return '—';
                    for (final k in keys) {
                      final v = act[k];
                      if (v != null &&
                          v.toString().isNotEmpty &&
                          v.toString() != 'null') {
                        return v.toString();
                      }
                    }
                    return '—';
                  }

                  // The timeline object from the API uses 'action' and 'user_name'
                  final action = field([
                    'action',
                    'type',
                    'activity_type',
                    'event',
                    'status',
                    'title',
                    'name',
                  ]);
                  final description = field([
                    'description',
                    'message',
                    'note',
                    'content',
                    'details',
                    'body',
                    'remarks',
                    'new_value', // timeline uses new_value for change details
                  ]);
                  final performedBy = field([
                    'user_name', // timeline API key
                    'performed_by',
                    'user',
                    'created_by',
                    'actor',
                    'performed_by_name',
                    'username',
                    'agent',
                    'agent_name',
                  ]);
                  final timestamp =
                      act is Map
                          ? (act['created_at'] ??
                                  act['timestamp'] ??
                                  act['performed_at'] ??
                                  act['updated_at'] ??
                                  act['date'])
                              ?.toString()
                          : null;

                  final color = _activityColor(action);
                  final icon = _activityIcon(action);

                  return _TimelineRow(
                    icon: icon,
                    color: color,
                    isLast: isLast,
                    action: action,
                    description:
                        (description != '—' && description.isNotEmpty)
                            ? description
                            : null,
                    performedBy:
                        (performedBy != '—' && performedBy.isNotEmpty)
                            ? performedBy
                            : null,
                    formattedDate:
                        timestamp != null ? _formatDate(timestamp) : null,
                    timeAgo: _timeAgo(timestamp),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline row
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isLast;
  final String action;
  final String? description;
  final String? performedBy;
  final String? formattedDate;
  final String timeAgo;

  const _TimelineRow({
    required this.icon,
    required this.color,
    required this.isLast,
    required this.action,
    required this.timeAgo,
    this.description,
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
                  if (description != null && description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF374151),
                        height: 1.45,
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
// Download button
// ─────────────────────────────────────────────────────────────────────────────

class _AttachmentDownloadButton extends StatelessWidget {
  final bool isDownloading;
  final bool hasId;
  final Color brandRed;
  final VoidCallback onTap;

  const _AttachmentDownloadButton({
    required this.isDownloading,
    required this.hasId,
    required this.brandRed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isDownloading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(brandRed),
        ),
      );
    }
    return GestureDetector(
      onTap: hasId ? onTap : null,
      child: Icon(
        Icons.download_outlined,
        color: hasId ? brandRed : const Color(0xFFCBD5E1),
        size: 20,
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
  Widget build(BuildContext context) {
    return Container(
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
  Widget build(BuildContext context) {
    return Container(
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
  Widget build(BuildContext context) {
    return Container(
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
                    color: Color(0xFF000000),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KVRow extends StatelessWidget {
  final String label;
  final String value;
  const _KVRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8A96A3),
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
              color: Color(0xFF000000),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEB1E23).withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFEB1E23),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFEB1E23), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
