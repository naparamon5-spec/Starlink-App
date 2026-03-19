import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../services/api_service.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _success = Color(0xFF24A148);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);
const _errorColor = Color(0xFFEB1E23);

const _dropItemStyle = TextStyle(
  color: _ink,
  fontSize: 14,
  fontWeight: FontWeight.w500,
);

// ── Allowed file extensions ────────────────────────────────────────────────────
const _allowedExtensions = [
  'jpg',
  'jpeg',
  'png',
  'gif',
  'pdf',
  'doc',
  'docx',
  'txt',
];

class AdminCreateTicketPage extends StatefulWidget {
  final String? bearerToken;
  const AdminCreateTicketPage({super.key, this.bearerToken});

  @override
  State<AdminCreateTicketPage> createState() => _AdminCreateTicketPageState();
}

class _AdminCreateTicketPageState extends State<AdminCreateTicketPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animController;

  // ── Form state ─────────────────────────────────────────────────────────────
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  Map<String, dynamic>? _selectedTicketType;
  Map<String, dynamic>? _selectedContact;
  Map<String, dynamic>? _selectedSubscription;

  // ── Attachment state ────────────────────────────────────────────────────────
  /// Each entry: { 'name': String, 'path': String, 'size': int, 'mimeType': String }
  final List<Map<String, dynamic>> _pickedFiles = [];

  // ── API data ───────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _ticketTypes = [];
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _subscriptions = [];

  // ── Loading / error states ─────────────────────────────────────────────────
  bool _isLoadingData = true;
  bool _isSubmitting = false;
  String? _loadError;

  bool _typeError = false;
  bool _contactError = false;
  bool _subscriptionError = false;
  bool _descriptionError = false;

  // ── HTTP client ────────────────────────────────────────────────────────────
  http.Client get _client {
    final httpClient =
        HttpClient()
          ..connectionTimeout = const Duration(seconds: 20)
          ..badCertificateCallback = (cert, host, port) => true;
    return IOClient(httpClient);
  }

  static const _baseUrl = 'https://starlink-api.ardentnetworks.com.ph';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _loadAllData();
  }

  @override
  void dispose() {
    _animController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    String? token = widget.bearerToken;
    if (token == null || token.isEmpty) {
      token = await ApiService.getValidAccessToken();
    }
    return token;
  }

  String _firstNonEmpty(Iterable<dynamic> values) {
    for (final v in values) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
    }
    return '';
  }

  String _extractSubscriptionId(Map<String, dynamic> sub) {
    // Backend expects a subscription identifier; in this project it's often the
    // service line number (varies by endpoint payload shape).
    return _firstNonEmpty([
      sub['service_line_number'],
      sub['serviceLineNumber'],
      sub['serviceLine'],
      sub['subscription_id'],
      sub['subscriptionId'],
      sub['id'],
    ]);
  }

  // ── Load all data in parallel ──────────────────────────────────────────────
  Future<void> _loadAllData() async {
    setState(() {
      _isLoadingData = true;
      _loadError = null;
    });

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _loadError = 'Session expired. Please log in again.';
          _isLoadingData = false;
        });
        return;
      }

      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final results = await Future.wait([
        _client
            .get(
              Uri.parse(
                '$_baseUrl/api/v1/subscriptions/paginated?page=1&limit=200',
              ),
              headers: headers,
            )
            .timeout(const Duration(seconds: 20)),
        _client
            .get(
              Uri.parse('$_baseUrl/api/v1/tickets/list/categories'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 20)),
        _client
            .get(
              Uri.parse('$_baseUrl/api/v1/users/list/contact/'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 20)),
      ]);

      final subsBody = json.decode(results[0].body);
      final typesBody = json.decode(results[1].body);
      final contactBody = json.decode(results[2].body);

      setState(() {
        if (results[0].statusCode == 200) {
          dynamic raw = subsBody['data'];
          if (raw is Map) raw = raw['data'] ?? raw;
          // Sanitize: replace null values with '' so label builders never crash
          _subscriptions =
              _asList(raw).map((item) {
                return Map<String, dynamic>.fromEntries(
                  item.entries.map((e) => MapEntry(e.key, e.value ?? '')),
                );
              }).toList();
        }

        if (results[1].statusCode == 200) {
          final raw = typesBody['data'] ?? typesBody['results'] ?? typesBody;
          _ticketTypes = _asList(raw);
        }

        if (results[2].statusCode == 200) {
          final raw =
              contactBody['data'] ?? contactBody['results'] ?? contactBody;
          _contacts =
              _asList(raw).map((e) {
                return <String, dynamic>{
                  'value': e['value'] ?? e['id'],
                  'label': (e['label'] ?? e['name'] ?? '').toString(),
                  ...e,
                };
              }).toList();
        }

        _isLoadingData = false;
      });

      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _animController.forward(),
      );
    } catch (e) {
      setState(() {
        _loadError = e.toString().replaceAll('Exception: ', '');
        _isLoadingData = false;
      });
    }
  }

  List<Map<String, dynamic>> _asList(dynamic raw) {
    if (raw is List) return raw.whereType<Map<String, dynamic>>().toList();
    if (raw is Map<String, dynamic>) return [raw];
    return [];
  }

  // ── File picker ────────────────────────────────────────────────────────────
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        withData: false, // use path, not bytes, to avoid memory pressure
      );

      if (result == null || result.files.isEmpty) return;

      setState(() {
        for (final f in result.files) {
          // Skip duplicates by name
          if (_pickedFiles.any((p) => p['name'] == f.name)) continue;
          _pickedFiles.add({
            'name': f.name,
            'path': f.path ?? '',
            'size': f.size,
            'mimeType': _mimeFromExtension(f.extension ?? ''),
          });
        }
      });
    } catch (e) {
      _showError(
        'Could not pick files: ${e.toString().replaceAll("Exception: ", "")}',
      );
    }
  }

  void _removeFile(int index) {
    setState(() => _pickedFiles.removeAt(index));
  }

  String _mimeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  IconData _iconForMime(String mime) {
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.contains('word')) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  // ── Submit — creates ticket then uploads attachments ───────────────────────
  Future<void> _submitTicket() async {
    setState(() {
      _typeError = _selectedTicketType == null;
      _contactError = _selectedContact == null;
      _subscriptionError = _selectedSubscription == null;
      _descriptionError = _descriptionController.text.trim().isEmpty;
    });

    if (_typeError ||
        _contactError ||
        _subscriptionError ||
        _descriptionError) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        _showError('Session expired. Please log in again.');
        setState(() => _isSubmitting = false);
        return;
      }

      final ticketTypeValue =
          _selectedTicketType!['id']?.toString() ??
          _selectedTicketType!['name']?.toString() ??
          _selectedTicketType!['category']?.toString() ??
          '';

      final subscriptionId = _extractSubscriptionId(_selectedSubscription!);
      if (subscriptionId.isEmpty) {
        setState(() {
          _subscriptionError = true;
        });
        _showError('Selected subscription is invalid. Please re-select.');
        return;
      }

      final contactValue =
          _selectedContact!['value']?.toString() ??
          _selectedContact!['id']?.toString() ??
          '';

      final body = json.encode({
        'description': _descriptionController.text.trim(),
        'ticket_type': ticketTypeValue,
        'subscription_id': subscriptionId,
        'contact': contactValue,
        if (_subjectController.text.trim().isNotEmpty)
          'subject': _subjectController.text.trim(),
      });

      // ── Step 1: Create the ticket ──────────────────────────────────────────
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/tickets/'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 20));

      final decoded = json.decode(response.body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        final msg =
            decoded is Map
                ? (decoded['message'] ??
                    decoded['detail'] ??
                    'Failed to create ticket.')
                : 'Failed to create ticket.';
        _showError(msg.toString());
        return;
      }

      // ── Step 2: Upload attachments if any ─────────────────────────────────
      if (_pickedFiles.isNotEmpty) {
        // Extract the new ticket ID from the response
        final ticketId =
            (decoded is Map
                    ? (decoded['data']?['id'] ??
                        decoded['data']?['ticket_id'] ??
                        decoded['id'] ??
                        decoded['ticket_id'])
                    : null)
                ?.toString() ??
            '';

        if (ticketId.isNotEmpty) {
          final uploadResult = await ApiService.uploadAttachments(
            ticketId: ticketId,
            files: _pickedFiles,
            bearerToken: token,
          );

          if (uploadResult['status'] != 'success') {
            // Ticket was created — warn but don't block success
            _showError(
              'Ticket created, but attachment upload failed: ${uploadResult['message']}',
            );
          }
        } else {
          _showError(
            'Ticket created, but could not determine ticket ID for attachments.',
          );
        }
      }

      // ── Success ────────────────────────────────────────────────────────────
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text(
                'Ticket created successfully!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build helpers ──────────────────────────────────────────────────────────

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _inkTertiary,
        letterSpacing: 1.1,
      ),
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );

  Widget _dropdown<T extends Map<String, dynamic>>({
    required String hint,
    required IconData icon,
    required List<T> items,
    required T? value,
    required String Function(T) labelBuilder,
    required void Function(T?) onChanged,
    required bool hasError,
    required String errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _surfaceSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError ? _errorColor : _border,
              width: hasError ? 1.5 : 1,
            ),
          ),
          child: DropdownButtonFormField<T>(
            initialValue: value,
            isExpanded: true,
            style: _dropItemStyle,
            dropdownColor: _surface,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: hasError ? _errorColor : _inkTertiary,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                size: 18,
                color: hasError ? _errorColor : _primary,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              hintText: hint,
              hintStyle: TextStyle(
                color: hasError ? _errorColor.withOpacity(0.7) : _inkTertiary,
                fontSize: 14,
              ),
            ),
            items:
                items.map((item) {
                  return DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      labelBuilder(item),
                      overflow: TextOverflow.ellipsis,
                      style: _dropItemStyle,
                    ),
                  );
                }).toList(),
            onChanged: (val) {
              onChanged(val);
              setState(() {});
            },
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              errorText,
              style: const TextStyle(
                color: _errorColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _textField(
    TextEditingController c,
    String hint,
    IconData icon, {
    int maxLines = 1,
    bool hasError = false,
    String errorText = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: _surfaceSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasError ? _errorColor : _border,
              width: hasError ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: c,
            maxLines: maxLines,
            style: const TextStyle(color: _ink, fontSize: 14),
            onChanged: (_) {
              if (hasError) {
                setState(() {
                  if (c == _descriptionController) _descriptionError = false;
                });
              }
            },
            decoration: InputDecoration(
              prefixIcon:
                  maxLines == 1
                      ? Icon(
                        icon,
                        size: 18,
                        color: hasError ? _errorColor : _primary,
                      )
                      : null,
              hintText: hint,
              hintStyle: TextStyle(
                color: hasError ? _errorColor.withOpacity(0.7) : _inkTertiary,
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: maxLines > 1 ? 16 : 12,
                vertical: 14,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              errorText,
              style: const TextStyle(
                color: _errorColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Label builders ─────────────────────────────────────────────────────────

  String _ticketTypeLabel(Map<String, dynamic> item) =>
      item['name']?.toString() ??
      item['category']?.toString() ??
      item['label']?.toString() ??
      '—';

  String _contactLabel(Map<String, dynamic> item) {
    final label = item['label']?.toString() ?? '';
    if (label.isNotEmpty) return label;
    final name = item['name']?.toString() ?? '';
    final email = item['email']?.toString() ?? '';
    if (name.isNotEmpty && email.isNotEmpty) return '$name ($email)';
    return name.isNotEmpty ? name : (email.isNotEmpty ? email : '—');
  }

  String _safeStr(Map<String, dynamic> item, String key) =>
      (item[key] == null ? '' : item[key].toString()).trim();

  String _subscriptionLabel(Map<String, dynamic> item) {
    final nickname = _safeStr(item, 'nickname');
    if (nickname.isNotEmpty) return nickname;
    final sln = _safeStr(item, 'service_line_number');
    if (sln.isNotEmpty) {
      final plan = _safeStr(item, 'plan_name');
      return plan.isNotEmpty ? '$sln – $plan' : sln;
    }
    final plan =
        _safeStr(item, 'plan_name').isNotEmpty
            ? _safeStr(item, 'plan_name')
            : _safeStr(item, 'name').isNotEmpty
            ? _safeStr(item, 'name')
            : _safeStr(item, 'subscription_name');
    if (plan.isNotEmpty) return plan;
    final id = _safeStr(item, 'id');
    return id.isNotEmpty ? 'Subscription #$id' : '—';
  }

  // ── Attachments section ────────────────────────────────────────────────────

  Widget _buildAttachmentsSection() {
    return _card(
      child: Column(
        children: [
          // Drop zone (visual only on mobile; tap triggers picker)
          GestureDetector(
            onTap: _pickFiles,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: _surfaceSubtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: _primary.withOpacity(0.2)),
                    ),
                    child: const Icon(
                      Icons.cloud_upload_outlined,
                      color: _primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tap to select files',
                    style: TextStyle(color: _inkSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Images, PDF, DOC, DOCX, TXT',
                    style: TextStyle(color: _inkTertiary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Choose Files button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickFiles,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'Choose Files',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),

          // Selected files list
          if (_pickedFiles.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: _border, height: 1),
            const SizedBox(height: 10),
            ...List.generate(_pickedFiles.length, (i) {
              final f = _pickedFiles[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _iconForMime(f['mimeType'] as String),
                        color: _primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f['name'] as String,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatFileSize(f['size'] as int),
                            style: const TextStyle(
                              fontSize: 11,
                              color: _inkTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _removeFile(i),
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                        color: _inkTertiary,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ── Main build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _surfaceSubtle,
        body: Column(
          children: [
            // ── Gradient AppBar ──────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEB1E23), Color(0xFF760F12)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Ticket',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Fill in the details below',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_isLoadingData && _loadError == null)
                        GestureDetector(
                          onTap: _isSubmitting ? null : _submitTicket,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(
                                _isSubmitting ? 0.08 : 0.18,
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child:
                                _isSubmitting
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text(
                                      'Submit',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child:
                  _isLoadingData
                      ? _buildLoading()
                      : _loadError != null
                      ? _buildErrorState()
                      : _buildForm(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: CircularProgressIndicator(color: _primary, strokeWidth: 2.5),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Loading ticket data...',
          style: TextStyle(
            color: _inkSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Fetching subscriptions, categories & contacts',
          style: TextStyle(color: _inkTertiary, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _buildErrorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline, color: _primary, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _inkSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadAllData,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text(
              'Retry',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildForm() => AnimatedBuilder(
    animation: _animController,
    builder:
        (_, child) => Opacity(
          opacity: _animController.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _animController.value)),
            child: child,
          ),
        ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject
          _sectionLabel('SUBJECT'),
          _card(
            child: _textField(
              _subjectController,
              'Enter ticket subject (optional)',
              Icons.title_outlined,
            ),
          ),
          const SizedBox(height: 20),

          // Ticket Type + Contact
          _sectionLabel('TICKET DETAILS'),
          _card(
            child: Column(
              children: [
                _dropdown<Map<String, dynamic>>(
                  hint: 'Select Type',
                  icon: Icons.confirmation_number_outlined,
                  items: _ticketTypes,
                  value: _selectedTicketType,
                  labelBuilder: _ticketTypeLabel,
                  hasError: _typeError,
                  errorText: 'Ticket type is required',
                  onChanged: (v) {
                    _selectedTicketType = v;
                    _typeError = false;
                  },
                ),
                const SizedBox(height: 14),
                _dropdown<Map<String, dynamic>>(
                  hint: 'Select Contact',
                  icon: Icons.person_outline,
                  items: _contacts,
                  value: _selectedContact,
                  labelBuilder: _contactLabel,
                  hasError: _contactError,
                  errorText: 'Contact is required',
                  onChanged: (v) {
                    _selectedContact = v;
                    _contactError = false;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Subscription
          _sectionLabel('SUBSCRIPTION'),
          _card(
            child: _dropdown<Map<String, dynamic>>(
              hint: 'Select Subscription',
              icon: Icons.router_outlined,
              items: _subscriptions,
              value: _selectedSubscription,
              labelBuilder: _subscriptionLabel,
              hasError: _subscriptionError,
              errorText: 'Subscription is required',
              onChanged: (v) {
                _selectedSubscription = v;
                _subscriptionError = false;
              },
            ),
          ),
          const SizedBox(height: 20),

          // Description
          _sectionLabel('DESCRIPTION'),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_descriptionError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: const [
                        Icon(Icons.error_outline, size: 14, color: _errorColor),
                        SizedBox(width: 4),
                        Text(
                          'Description is required',
                          style: TextStyle(
                            color: _errorColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: _surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _descriptionError ? _errorColor : _border,
                      width: _descriptionError ? 1.5 : 1,
                    ),
                  ),
                  child: TextField(
                    controller: _descriptionController,
                    maxLines: 6,
                    onChanged: (_) {
                      if (_descriptionError) {
                        setState(() => _descriptionError = false);
                      }
                    },
                    style: const TextStyle(color: _ink, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Describe the issue in detail...',
                      hintStyle: TextStyle(
                        color:
                            _descriptionError
                                ? _errorColor.withOpacity(0.6)
                                : _inkTertiary,
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Attachments
          _sectionLabel('ATTACHMENTS'),
          _buildAttachmentsSection(),
          const SizedBox(height: 28),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _isSubmitting ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _inkSecondary,
                    side: const BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitTicket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _primary.withOpacity(0.5),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon:
                      _isSubmitting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    _isSubmitting ? 'Submitting...' : 'Submit Ticket',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
