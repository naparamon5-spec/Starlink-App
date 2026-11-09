import 'package:starlink_app/shared/widgets/app_dialog.dart';
import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/core/utils/file_download/file_downloader.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/resolve_remarks_dialog.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';
import 'package:starlink_app/shared/widgets/unsaved_changes_guard.dart';

/// Same list and size the API enforces for ticket attachments.
const _allowedExtensions = [
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'heic',
  'heif',
  'pdf',
  'doc',
  'docx',
  'txt',
];
const _maxAttachmentBytes = 10 * 1024 * 1024;
const _imageExtensions = {
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'heic',
  'heif',
};

String _text(dynamic v) {
  final t = v?.toString().trim() ?? '';
  return t == 'null' ? '' : t;
}

DateTime? _parseDate(dynamic v) => DateTime.tryParse(_text(v))?.toLocal();

String _dateTime(dynamic v) {
  final d = _parseDate(v);
  return d == null ? '—' : DateFormat('MMM dd, y, h:mm a').format(d);
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  return (parts.length > 1 ? '$first${parts.last[0]}' : first).toUpperCase();
}

Color _statusColor(String status) => switch (status) {
  'open' || 'in_progress' => AppColors.info,
  'resolved' => AppColors.success,
  _ => AppColors.inkMuted,
};

String _statusLabel(String status) => status.replaceAll('_', ' ').toUpperCase();

/// Whether an attachment belongs under Images. The file name counts too:
/// images uploaded from the app used to be stored as application/octet-stream.
bool isImageAttachment(Map<String, dynamic> att) {
  if (_text(att['file_type']).toLowerCase().contains('image')) return true;
  final name = _attachmentName(att).toLowerCase();
  return _imageExtensions.contains(name.split('.').last);
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
    normalized = normalized.padRight(normalized.length + (4 - remainder), '=');
  }

  return base64Decode(normalized);
}

/// An image attachment's bytes, downloaded once per [cache]. A failed load
/// isn't kept, so opening the image again retries it.
Future<Uint8List?> _imageBytes(
  Map<String, dynamic> att,
  Map<String, Future<Uint8List?>> cache,
) {
  final id = _text(att['id'] ?? att['attachment_id']);
  if (id.isEmpty) return Future.value(null);
  return cache.putIfAbsent(id, () async {
    Uint8List? bytes;
    try {
      final result = await ApiService.downloadAttachment(id);
      final data = _text(result['base64']);
      if (result['status'] == 'success' && data.isNotEmpty) {
        bytes = _decodeBase64Data(data);
      }
    } catch (_) {
      // Shown as a preview that isn't available.
    }
    if (bytes == null) cache.remove(id);
    return bytes;
  });
}

String _attachmentName(Map<String, dynamic> att) {
  final name = _text(att['original_name']);
  if (name.isNotEmpty) return name;
  final file = _text(att['file_name']);
  return file.isNotEmpty ? file : 'attachment';
}

/// A ticket for every role: the conversation first, with the requester,
/// attachments and timeline one tap away under Details, like the web portal.
/// Pops with `{id, status}` when the status changed, for lists to update.
class TicketDetailsView extends StatefulWidget {
  const TicketDetailsView({super.key, required this.ticketId, this.subject});

  final String ticketId;
  final String? subject;

  @override
  State<TicketDetailsView> createState() => _TicketDetailsViewState();
}

class _TicketDetailsViewState extends State<TicketDetailsView> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  final _attachments = ValueNotifier<List<Map<String, dynamic>>>(const []);
  final _detail = ValueNotifier<Map<String, dynamic>?>(null);
  final _downloading = ValueNotifier<String?>(null);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _comments = const [];
  String _myUserId = '';
  bool _posting = false;
  bool _acting = false;
  bool _descriptionOpen = false;
  String? _initialStatus;
  String? _panelTab;

  String get _status =>
      _text(_detail.value?['status']).toLowerCase().replaceAll(' ', '_');
  bool get _isOpen => _status == 'open';
  bool get _isInProgress => _status == 'in_progress';

  /// `flag` is the API's answer to "can this account accept and resolve?"
  bool get _canAct => _detail.value?['flag'] == true;

  String get _composerHint {
    if (_isInProgress) return 'Type a message';
    if (_isOpen) {
      return _canAct
          ? 'Accept the ticket to start the conversation'
          : 'You can reply once an agent accepts this ticket';
    }
    return 'This ticket is closed to new messages';
  }

  @override
  void initState() {
    super.initState();
    _composer.addListener(() => setState(() {}));
    _loadMe();
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    _attachments.dispose();
    _detail.dispose();
    _downloading.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    final prefs = await SharedPreferences.getInstance();
    final id = _text(prefs.get('user_id'));
    if (mounted) setState(() => _myUserId = id);
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic> res) {
    if (res['status'] != 'success' || res['data'] is! List) return const [];
    return (res['data'] as List)
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final results = await Future.wait([
      ApiService.getTicketById(widget.ticketId),
      ApiService.getTicketComments(widget.ticketId),
      ApiService.getTicketAttachments(widget.ticketId),
    ]);
    if (!mounted) return;
    final detail = results[0];
    final data = detail['data'];
    if (detail['status'] != 'success' || data is! Map) {
      setState(() {
        _loading = false;
        if (_detail.value == null) {
          _error =
              _text(detail['message']).isNotEmpty
                  ? _text(detail['message'])
                  : "This ticket is unavailable or you don't have access.";
        }
      });
      return;
    }
    final comments = _rows(results[1])..sort((a, b) {
      final x = _parseDate(a['date'] ?? a['created_at']);
      final y = _parseDate(b['date'] ?? b['created_at']);
      if (x == null || y == null) return 0;
      return x.compareTo(y);
    });
    setState(() {
      _detail.value = Map<String, dynamic>.from(data);
      _initialStatus ??= _status;
      _comments = comments;
      _attachments.value = _rows(results[2]);
      _loading = false;
      _error = null;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _snack(String message, {bool isError = false}) => AppToast.result(context, message, ok: !isError);

  Future<void> _leave() async {
    if (_composer.text.trim().isNotEmpty &&
        !await confirmDiscardChanges(context)) {
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      _status != _initialStatus && _status.isNotEmpty
          ? {'id': widget.ticketId, 'status': _statusLabel(_status)}
          : null,
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _post() async {
    final text = _composer.text.trim();
    if (!_isInProgress || text.isEmpty || _posting) return;
    setState(() => _posting = true);
    final res = await ApiService.addTicketComment(widget.ticketId, text);
    if (!mounted) return;
    if (res['status'] == 'success') {
      _composer.clear();
      final comments = await ApiService.getTicketComments(widget.ticketId);
      if (!mounted) return;
      setState(() => _comments = _rows(comments));
      _scrollToBottom();
    } else {
      _snack(
        _text(res['message']).isNotEmpty
            ? _text(res['message'])
            : "Couldn't send your message. Try again.", isError: true);
    }
    setState(() => _posting = false);
  }

  Future<void> _runAction(
    Future<Map<String, dynamic>> Function() action,
    String? done,
  ) async {
    setState(() => _acting = true);
    final res = await action();
    if (!mounted) return;
    if (res['status'] != 'success') {
      _snack(
        _text(res['message']).isNotEmpty
            ? _text(res['message'])
            : "Couldn't update the ticket. Try again.", isError: true);
    } else if (done != null) {
      _snack(done);
    }
    await _load(quiet: true);
    if (mounted) setState(() => _acting = false);
  }

  // The badge and buttons change, and a snack bar would cover the message box
  // the person is about to use.
  void _accept() =>
      _runAction(() => ApiService.acceptTicket(widget.ticketId), null);

  Future<void> _resolve() async {
    final remarks = await askResolveRemarks(context);
    if (remarks == null || !mounted) return;
    _runAction(
      () => ApiService.resolveTicket(widget.ticketId, remarks: remarks),
      'Ticket resolved',
    );
  }

  Future<void> _close() async {
    final ok = await showAppConfirm(context, title: 'Close this ticket?', message: 'No more messages can be added once closed.', confirmLabel: 'Close ticket', icon: Icons.task_alt_rounded);
    if (ok != true || !mounted) return;
    _runAction(() => ApiService.closeTicket(widget.ticketId), 'Ticket closed');
  }

  /// Returns the panel tab the upload landed in, or null if nothing uploaded.
  Future<String?> _upload() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
      );
      if (picked == null || !mounted) return null;
      final files = <Map<String, dynamic>>[];
      for (final f in picked.files) {
        if (f.size > _maxAttachmentBytes) {
          _snack('${f.name} is over the 10 MB limit.', isError: true);
        } else if ((f.path ?? '').isNotEmpty) {
          files.add({'name': f.name, 'path': f.path});
        }
      }
      if (files.isEmpty) return null;
      final res = await ApiService.uploadAttachments(
        ticketId: widget.ticketId,
        files: files,
      );
      if (!mounted) return null;
      if (res['status'] != 'success') {
        _snack(
          _text(res['message']).isNotEmpty
              ? _text(res['message'])
              : "Couldn't upload. Try again.", isError: true);
        return null;
      }
      final list = await ApiService.getTicketAttachments(widget.ticketId);
      if (!mounted) return null;
      _attachments.value = _rows(list);
      _snack(
        files.length == 1
            ? 'Attachment uploaded'
            : '${files.length} attachments uploaded',
      );
      final allImages = files.every(
        (f) => _imageExtensions.contains(
          f['name'].toString().split('.').last.toLowerCase(),
        ),
      );
      return allImages ? 'images' : 'files';
    } catch (_) {
      if (mounted) _snack("Couldn't open the file picker. Try again.", isError: true);
      return null;
    }
  }

  Future<void> _download(Map<String, dynamic> att) async {
    final id = _text(att['id'] ?? att['attachment_id']);
    if (id.isEmpty) {
      _snack("Can't download this file: its ID is missing.", isError: true);
      return;
    }
    _downloading.value = id;
    try {
      final result = await ApiService.downloadAttachment(id);
      if (!mounted) return;
      final base64Str = _text(result['base64']);
      if (result['status'] != 'success' || base64Str.isEmpty) {
        _snack(
          _text(result['message']).isNotEmpty
              ? _text(result['message'])
              : 'Download failed.', isError: true);
        return;
      }
      final bytes = _decodeBase64Data(base64Str);
      final rawName =
          _text(result['filename']).isNotEmpty &&
                  _text(result['filename']) != 'attachment'
              ? _text(result['filename'])
              : _attachmentName(att);
      final mimeType = _resolveMimeType(
        apiMime: result['mimeType']?.toString(),
        filename: rawName,
        bytes: bytes,
      );
      final filename = _ensureFilenameHasExtension(
        rawName,
        mimeType: mimeType,
        bytes: bytes,
      );
      final path = await saveBytesAsFile(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType,
      );
      if (!mounted) return;
      if (path == null && !kIsWeb) {
        _snack("Couldn't save $filename.", isError: true);
        return;
      }
      _snack(
        path != null && path.isNotEmpty
            ? 'Saved ${path.split('/').last} to ${savedLocationLabel(path)}'
            : 'Downloaded $filename',
      );
    } catch (_) {
      if (mounted) _snack('Download failed.', isError: true);
    } finally {
      _downloading.value = null;
    }
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

  void _openDetails() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (_) => _DetailsPanel(
              detail: _detail,
              attachments: _attachments,
              downloading: _downloading,
              initialTab: _panelTab,
              onTabChanged: (t) => _panelTab = t,
              onUpload: _upload,
              onDownload: _download,
            ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final code = 'TKT-${widget.ticketId.padLeft(6, '0')}';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.paperSubtle,
        appBar: AppBar(
          leading: BackButton(onPressed: _leave),
          title: Text(code),
          actions: [
            if (_detail.value != null)
              TextButton.icon(
                onPressed: _openDetails,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.vertical_split_outlined, size: 18),
                label: const Text('Details'),
              ),
            const SizedBox(width: 4),
          ],
        ),
        body:
            _loading && _detail.value == null
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildError()
                : Column(
                  children: [
                    _buildHeader(),
                    Expanded(child: _buildThread()),
                    _buildComposer(),
                  ],
                ),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 34, color: AppColors.inkFaint),
          const SizedBox(height: 10),
          const Text(
            'Ticket not found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: _load, child: const Text('Try again')),
        ],
      ),
    ),
  );

  Widget _buildHeader() {
    final d = _detail.value!;
    final subject = _text(d['subject']);
    final description = _text(d['description']);
    const compact = Size(0, 34);
    const padding = EdgeInsets.symmetric(horizontal: 14);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DotBadge(_statusLabel(_status), color: _statusColor(_status)),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (_canAct && _isOpen)
                      OutlinedButton(
                        onPressed: _acting ? null : _accept,
                        style: OutlinedButton.styleFrom(
                          minimumSize: compact,
                          padding: padding,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Accept'),
                      ),
                    if (_canAct && _isInProgress)
                      FilledButton(
                        onPressed: _acting ? null : _resolve,
                        style: FilledButton.styleFrom(
                          minimumSize: compact,
                          padding: padding,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Resolve'),
                      ),
                    if (_isInProgress)
                      TextButton(
                        onPressed: _acting ? null : _close,
                        style: TextButton.styleFrom(
                          minimumSize: compact,
                          padding: padding,
                          foregroundColor: AppColors.ink,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Close'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subject.isNotEmpty ? subject : (widget.subject ?? 'Ticket'),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: AppColors.ink,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 3),
            InkWell(
              onTap: () => setState(() => _descriptionOpen = !_descriptionOpen),
              child: Text(
                description,
                maxLines: _descriptionOpen ? null : 3,
                overflow: _descriptionOpen ? null : TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThread() {
    if (_comments.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(quiet: true),
        child: LayoutBuilder(
          builder:
              (context, box) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: box.maxHeight,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 28,
                          color: AppColors.inkFaint,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No messages yet.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(quiet: true),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        itemCount: _comments.length,
        itemBuilder: (context, i) {
          final c = _comments[i];
          final at = _parseDate(c['date'] ?? c['created_at']);
          final prev =
              i == 0
                  ? null
                  : _parseDate(
                    _comments[i - 1]['date'] ?? _comments[i - 1]['created_at'],
                  );
          final newDay =
              at != null &&
              (i == 0 || prev == null || !DateUtils.isSameDay(at, prev));
          return Column(
            children: [
              if (newDay) _DaySeparator(at),
              _MessageBubble(
                name: _text(c['name']).isNotEmpty ? _text(c['name']) : 'User',
                text: _text(c['comment']),
                time: at == null ? '' : DateFormat('h:mm a').format(at),
                mine: _myUserId.isNotEmpty && _text(c['user_id']) == _myUserId,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildComposer() {
    final canSend =
        _isInProgress && _composer.text.trim().isNotEmpty && !_posting;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            decoration: BoxDecoration(
              color: AppColors.paperSubtle,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Upload images or files',
                  visualDensity: VisualDensity.compact,
                  onPressed: _upload,
                  icon: const Icon(
                    Icons.add_rounded,
                    size: 22,
                    color: AppColors.inkMuted,
                  ),
                ),
                if (!_isInProgress) ...[
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: AppColors.inkFaint,
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: TextField(
                    controller: _composer,
                    enabled: _isInProgress,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      hintText: _composerHint,
                      hintMaxLines: 2,
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Material(
                    color: canSend ? AppColors.brand : AppColors.lineStrong,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: canSend ? _post : null,
                      child:
                          _posting
                              ? const Padding(
                                padding: EdgeInsets.all(11),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(
                                Icons.send_rounded,
                                size: 18,
                                color: Colors.white,
                                semanticLabel: 'Send',
                              ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator(this.date);
  final DateTime date;

  String get _label {
    final now = DateTime.now();
    if (DateUtils.isSameDay(date, now)) return 'Today';
    if (DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return DateFormat('EEEE, MMMM d').format(date);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.paperMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.inkMuted,
        ),
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.name);
  final String name;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 15,
    backgroundColor: AppColors.navy,
    child: Text(
      _initials(name),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.name,
    required this.text,
    required this.time,
    required this.mine,
  });
  final String name;
  final String text;
  final String time;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(14);
    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      decoration: BoxDecoration(
        color: mine ? AppColors.navy : AppColors.paper,
        border: mine ? null : Border.all(color: AppColors.line),
        borderRadius: BorderRadius.only(
          topLeft: radius,
          topRight: radius,
          bottomLeft: mine ? radius : const Radius.circular(4),
          bottomRight: mine ? const Radius.circular(4) : radius,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.35,
              color: mine ? Colors.white : AppColors.ink,
            ),
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: mine ? Colors.white60 : AppColors.inkFaint,
              ),
            ),
          ],
        ],
      ),
    );
    final content = Flexible(
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: name,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
              children: [
                if (mine)
                  const TextSpan(
                    text: ' (You)',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: AppColors.inkFaint,
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          bubble,
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: mine ? 28 : 0),
          if (!mine) ...[_Avatar(name), const SizedBox(width: 8)],
          content,
          if (mine) ...[const SizedBox(width: 8), _Avatar(name)],
          SizedBox(width: mine ? 0 : 28),
        ],
      ),
    );
  }
}

// ── Details panel ──────────────────────────────────────────────────────────

class _DetailsPanel extends StatefulWidget {
  const _DetailsPanel({
    required this.detail,
    required this.attachments,
    required this.downloading,
    required this.initialTab,
    required this.onTabChanged,
    required this.onUpload,
    required this.onDownload,
  });

  final ValueNotifier<Map<String, dynamic>?> detail;
  final ValueNotifier<List<Map<String, dynamic>>> attachments;
  final ValueNotifier<String?> downloading;
  final String? initialTab;
  final ValueChanged<String> onTabChanged;
  final Future<String?> Function() onUpload;
  final Future<void> Function(Map<String, dynamic>) onDownload;

  @override
  State<_DetailsPanel> createState() => _DetailsPanelState();
}

class _DetailsPanelState extends State<_DetailsPanel> {
  late String _tab;

  @override
  void initState() {
    super.initState();
    // First opens on the first tab with something in it, then stays put.
    final all = widget.attachments.value;
    _tab =
        widget.initialTab ??
        (all.any(isImageAttachment)
            ? 'images'
            : all.isNotEmpty
            ? 'files'
            : 'timeline');
  }

  final _imageCache = <String, Future<Uint8List?>>{};

  void _select(String tab) {
    setState(() => _tab = tab);
    widget.onTabChanged(tab);
  }

  Future<void> _upload() async {
    final landed = await widget.onUpload();
    if (landed != null && mounted) _select(landed);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail.value ?? const <String, dynamic>{};
    final requester = _text(d['created_by']);
    final timeline =
        d['timeline'] is List
            ? (d['timeline'] as List)
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList()
            : const <Map<String, dynamic>>[];
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _RequesterHeader(name: requester),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _Properties(detail: d),
          ),
          ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: widget.attachments,
            builder: (context, all, _) {
              final images = all.where(isImageAttachment).toList();
              final files = all.where((a) => !isImageAttachment(a)).toList();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Tabs(
                      selected: _tab,
                      counts: {
                        'images': images.length,
                        'files': files.length,
                        'timeline': timeline.length,
                      },
                      onSelect: _select,
                      onUpload: _tab == 'timeline' ? null : _upload,
                    ),
                    const SizedBox(height: 14),
                    if (_tab == 'images')
                      _ImagesTab(
                        images: images,
                        cache: _imageCache,
                        downloading: widget.downloading,
                        onDownload: widget.onDownload,
                      )
                    else if (_tab == 'files')
                      _FilesTab(
                        files: files,
                        downloading: widget.downloading,
                        onDownload: widget.onDownload,
                      )
                    else
                      _TimelineTab(entries: timeline),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RequesterHeader extends StatelessWidget {
  const _RequesterHeader({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.navy,
    padding: const EdgeInsets.fromLTRB(18, 0, 8, 18),
    child: SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Close details',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
          Text(
            _initials(name),
            style: const TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w800,
              height: 1,
              letterSpacing: -1,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name.isEmpty ? '—' : name.toUpperCase(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'REQUESTER',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.6,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    ),
  );
}

class _Properties extends StatelessWidget {
  const _Properties({required this.detail});
  final Map<String, dynamic> detail;

  @override
  Widget build(BuildContext context) {
    final requester = _text(detail['created_by']);
    final email = _text(detail['created_by_email']);
    final company =
        _text(detail['company_name']).isNotEmpty
            ? _text(detail['company_name'])
            : _text(detail['end_user_name']);
    final line = _text(detail['subscription_id']);
    final type = _text(detail['ticket_type']);
    const value = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppColors.ink,
    );
    final rows = <Widget>[
      _PropertyRow(
        'Requester',
        Row(
          children: [
            _Avatar(requester),
            const SizedBox(width: 8),
            Expanded(child: Text(requester, style: value)),
          ],
        ),
      ),
      if (email.isNotEmpty) _PropertyRow('Email', Text(email, style: value)),
      if (company.isNotEmpty)
        _PropertyRow('Company', Text(company, style: value)),
      if (line.isNotEmpty)
        _PropertyRow('Service line', Text(line, style: value)),
      _PropertyRow(
        'Type',
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              type.isEmpty ? '—' : type.toUpperCase(),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: AppColors.navy,
              ),
            ),
          ),
        ),
      ),
      _PropertyRow(
        'Created',
        Text(_dateTime(detail['created_at']), style: value),
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow(this.label, this.child);
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted),
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.selected,
    required this.counts,
    required this.onSelect,
    required this.onUpload,
  });
  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onSelect;
  final VoidCallback? onUpload;

  static const _labels = {
    'images': 'Images',
    'files': 'Files',
    'timeline': 'Timeline',
  };

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final e in _labels.entries)
        Expanded(
          child: InkWell(
            onTap: () => onSelect(e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected == e.key ? AppColors.brand : AppColors.line,
                    width: selected == e.key ? 2 : 1,
                  ),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            selected == e.key
                                ? AppColors.ink
                                : AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color:
                            selected == e.key
                                ? AppColors.brand.withValues(alpha: 0.1)
                                : AppColors.paperMuted,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${counts[e.key] ?? 0}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color:
                              selected == e.key
                                  ? AppColors.brand
                                  : AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      if (onUpload != null)
        IconButton(
          tooltip: 'Upload images or files',
          visualDensity: VisualDensity.compact,
          onPressed: onUpload,
          icon: const Icon(
            Icons.file_upload_outlined,
            size: 20,
            color: AppColors.inkMuted,
          ),
        ),
    ],
  );
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Text(
    message,
    style: const TextStyle(fontSize: 12.5, color: AppColors.inkFaint),
  );
}

class _ImagesTab extends StatelessWidget {
  const _ImagesTab({
    required this.images,
    required this.cache,
    required this.downloading,
    required this.onDownload,
  });
  final List<Map<String, dynamic>> images;
  final Map<String, Future<Uint8List?>> cache;
  final ValueNotifier<String?> downloading;
  final Future<void> Function(Map<String, dynamic>) onDownload;

  void _open(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder:
            (_) => _ImageViewer(
              images: images,
              initialIndex: index,
              cache: cache,
              downloading: downloading,
              onDownload: onDownload,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const _EmptyTab('No images');
    return GridView.extent(
      maxCrossAxisExtent: 150,
      padding: EdgeInsets.zero, // Otherwise it adds the notch height on top.
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < images.length; i++)
          _ImageThumb(
            key: ValueKey(_text(images[i]['id'])),
            image: images[i],
            cache: cache,
            onTap: () => _open(context, i),
          ),
      ],
    );
  }
}

class _ImageThumb extends StatefulWidget {
  const _ImageThumb({
    super.key,
    required this.image,
    required this.cache,
    required this.onTap,
  });
  final Map<String, dynamic> image;
  final Map<String, Future<Uint8List?>> cache;
  final VoidCallback onTap;

  @override
  State<_ImageThumb> createState() => _ImageThumbState();
}

class _ImageThumbState extends State<_ImageThumb> {
  late final Future<Uint8List?> _bytes = _imageBytes(
    widget.image,
    widget.cache,
  );

  Widget _placeholder() => Container(
    color: AppColors.paperSubtle,
    padding: const EdgeInsets.all(8),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.image_outlined, size: 26, color: AppColors.navy),
        const SizedBox(height: 6),
        Text(
          _attachmentName(widget.image),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    button: true,
    label: _attachmentName(widget.image),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: _bytes,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const ColoredBox(
                  color: AppColors.paperSubtle,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final bytes = snap.data;
              if (bytes == null) return _placeholder();
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                cacheWidth: 400,
                errorBuilder: (_, __, ___) => _placeholder(),
              );
            },
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(onTap: widget.onTap),
          ),
        ],
      ),
    ),
  );
}

/// Full-screen images: swipe between them, pinch or double-tap to zoom.
class _ImageViewer extends StatefulWidget {
  const _ImageViewer({
    required this.images,
    required this.initialIndex,
    required this.cache,
    required this.downloading,
    required this.onDownload,
  });
  final List<Map<String, dynamic>> images;
  final int initialIndex;
  final Map<String, Future<Uint8List?>> cache;
  final ValueNotifier<String?> downloading;
  final Future<void> Function(Map<String, dynamic>) onDownload;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.images[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
        title: Text(
          widget.images.length > 1
              ? '${_index + 1} of ${widget.images.length}'
              : _attachmentName(current),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        actions: [
          ValueListenableBuilder<String?>(
            valueListenable: widget.downloading,
            builder:
                (context, busy, _) =>
                    busy != null && busy == _text(current['id'])
                        ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        )
                        : IconButton(
                          tooltip: 'Download',
                          onPressed: () => widget.onDownload(current),
                          icon: const Icon(
                            Icons.file_download_outlined,
                            color: Colors.white,
                          ),
                        ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        // A zoomed image needs its drags for panning.
        physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
        itemCount: widget.images.length,
        onPageChanged:
            (i) => setState(() {
              _index = i;
              _zoomed = false;
            }),
        itemBuilder:
            (_, i) => _ZoomableImage(
              image: widget.images[i],
              cache: widget.cache,
              onZoomChanged: (z) {
                if (mounted && z != _zoomed) setState(() => _zoomed = z);
              },
            ),
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({
    required this.image,
    required this.cache,
    required this.onZoomChanged,
  });
  final Map<String, dynamic> image;
  final Map<String, Future<Uint8List?>> cache;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _zoom = TransformationController();
  late final Future<Uint8List?> _bytes = _imageBytes(
    widget.image,
    widget.cache,
  );

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  bool get _isZoomed => _zoom.value.getMaxScaleOnAxis() > 1.01;

  void _toggleZoom(TapDownDetails details) {
    if (_isZoomed) {
      _zoom.value = Matrix4.identity();
    } else {
      final p = details.localPosition;
      _zoom.value =
          Matrix4.identity()
            ..translateByDouble(-p.dx, -p.dy, 0, 1)
            ..scaleByDouble(2, 2, 1, 1);
    }
    widget.onZoomChanged(_isZoomed);
  }

  Widget _unavailable() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            size: 40,
            color: Colors.white70,
          ),
          const SizedBox(height: 10),
          Text(
            "Can't preview ${_attachmentName(widget.image)}",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _bytes,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }
      final bytes = snap.data;
      if (bytes == null) return _unavailable();
      TapDownDetails? lastTap;
      return GestureDetector(
        onDoubleTapDown: (d) => lastTap = d,
        onDoubleTap: () {
          if (lastTap != null) _toggleZoom(lastTap!);
        },
        child: InteractiveViewer(
          transformationController: _zoom,
          minScale: 1,
          maxScale: 5,
          onInteractionEnd: (_) => widget.onZoomChanged(_isZoomed),
          child: Center(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _unavailable(),
            ),
          ),
        ),
      );
    },
  );
}

class _FilesTab extends StatelessWidget {
  const _FilesTab({
    required this.files,
    required this.downloading,
    required this.onDownload,
  });
  final List<Map<String, dynamic>> files;
  final ValueNotifier<String?> downloading;
  final Future<void> Function(Map<String, dynamic>) onDownload;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const _EmptyTab('No files');
    return ValueListenableBuilder<String?>(
      valueListenable: downloading,
      builder:
          (context, busy, _) => Column(
            children: [
              for (var i = 0; i < files.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                Row(
                  children: [
                    const Icon(
                      Icons.attach_file_rounded,
                      size: 17,
                      color: AppColors.navy,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _attachmentName(files[i]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    busy != null && busy == _text(files[i]['id'])
                        ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                        : IconButton(
                          tooltip: 'Download',
                          onPressed: () => onDownload(files[i]),
                          icon: const Icon(
                            Icons.file_download_outlined,
                            size: 20,
                            color: AppColors.inkMuted,
                          ),
                        ),
                  ],
                ),
              ],
            ],
          ),
    );
  }
}

class _TimelineTab extends StatelessWidget {
  const _TimelineTab({required this.entries});
  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const _EmptyTab('No activity recorded yet.');
    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: AppColors.navy.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: AppColors.navy,
                      ),
                    ),
                    if (i < entries.length - 1)
                      Expanded(
                        child: Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          color: AppColors.line,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(child: _timelineEntry(entries[i])),
              ],
            ),
          ),
      ],
    );
  }

  Widget _timelineEntry(Map<String, dynamic> t) {
    final user = _text(t['user_name']);
    final next = _text(t['new_value']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.3,
                color: AppColors.inkMuted,
              ),
              children: [
                TextSpan(
                  text: user.isEmpty ? 'System' : user,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                TextSpan(text: ' ${_text(t['action'])}'),
                if (next.isNotEmpty) ...[
                  const TextSpan(text: ' → '),
                  TextSpan(
                    text: next,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _dateTime(t['created_at']),
            style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }
}
