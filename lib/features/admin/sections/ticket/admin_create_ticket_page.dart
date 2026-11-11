import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/shared/widgets/unsaved_changes_guard.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:file_picker/file_picker.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/ui_kit.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFF133341);
const _success = Color(0xFF10B981);
const _ink = Color(0xFF111111);
const _inkSecondary = Color(0xFF666666);
const _inkTertiary = Color(0xFF888888);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF8F8F8);
const _border = Color(0xFFD7D7D7);
const _errorColor = Color(0xFFE90408);

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
  late AnimationController _animController;

  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  Map<String, dynamic>? _selectedTicketType;
  Map<String, dynamic>? _selectedContact;
  Map<String, dynamic>? _selectedSubscription;

  final List<Map<String, dynamic>> _pickedFiles = [];

  List<Map<String, dynamic>> _ticketTypes = [];
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _subscriptions = [];

  bool _isLoadingData = true;
  bool _isSubmitting = false;
  String? _loadError;

  bool _typeError = false;
  bool _contactError = false;
  bool _subscriptionError = false;
  bool _descriptionError = false;

  http.Client get _client {
    final httpClient =
        HttpClient()
          ..connectionTimeout = const Duration(seconds: 20);
    return IOClient(httpClient);
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      value: 1.0,
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
    return _firstNonEmpty([
      sub['service_line_number'],
      sub['serviceLineNumber'],
      sub['serviceLine'],
      sub['subscription_id'],
      sub['subscriptionId'],
      sub['id'],
    ]);
  }

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
                '${ApiService.baseUrl}/v1/subscriptions/paginated?page=1&limit=200',
              ),
              headers: headers,
            )
            .timeout(const Duration(seconds: 20)),
        _client
            .get(
              Uri.parse('${ApiService.baseUrl}/v1/tickets/list/categories'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 20)),
        _client
            .get(
              Uri.parse('${ApiService.baseUrl}/v1/users/list/contact/'),
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

  // ── Custom bottom sheet picker ─────────────────────────────────────────────

  Future<void> _showPicker<T extends Map<String, dynamic>>({
    required String title,
    required List<T> items,
    required T? selected,
    required String Function(T) labelBuilder,
    required String Function(T) subtitleBuilder,
    required void Function(T) onSelect,
  }) async {
    final searchController = TextEditingController();
    List<T> filtered = List.from(items);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _primary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _surfaceSubtle,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: _inkSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: TextField(
                        controller: searchController,
                        autofocus: false,
                        style: const TextStyle(fontSize: 14, color: _ink),
                        onChanged: (q) {
                          final lower = q.toLowerCase();
                          setModalState(() {
                            filtered =
                                items
                                    .where(
                                      (item) =>
                                          labelBuilder(
                                            item,
                                          ).toLowerCase().contains(lower) ||
                                          subtitleBuilder(
                                            item,
                                          ).toLowerCase().contains(lower),
                                    )
                                    .toList();
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search…',
                          hintStyle: TextStyle(
                            color: _inkTertiary,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: _inkTertiary,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // List
                  Expanded(
                    child:
                        filtered.isEmpty
                            ? const Center(
                              child: Text(
                                'No results found',
                                style: TextStyle(
                                  color: _inkTertiary,
                                  fontSize: 14,
                                ),
                              ),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final item = filtered[i];
                                final label = labelBuilder(item);
                                final subtitle = subtitleBuilder(item);
                                final isSelected =
                                    selected != null &&
                                    labelBuilder(selected) == label;

                                return InkWell(
                                  onTap: () {
                                    onSelect(item);
                                    Navigator.pop(ctx);
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? _primary.withOpacity(0.06)
                                              : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color:
                                            isSelected
                                                ? _primary.withOpacity(0.5)
                                                : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Avatar/initial
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color:
                                                isSelected
                                                    ? _primary
                                                    : _primary.withOpacity(
                                                      0.08,
                                                    ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            _optionIcon(label),

                                            size: 20,

                                            color:
                                                isSelected
                                                    ? Colors.white
                                                    : _primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                label,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      isSelected
                                                          ? _primary
                                                          : _ink,
                                                ),
                                              ),
                                              if (subtitle.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  subtitle,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: _inkTertiary,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          isSelected
                                              ? Icons.check_circle_rounded
                                              : Icons.chevron_right_rounded,

                                          color:
                                              isSelected
                                                  ? _primary
                                                  : const Color(0xFF94A3B8),

                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Tap-to-open selector tile ──────────────────────────────────────────────

  IconData _optionIcon(String label) {
    final l = label.toLowerCase();
    if (l.contains('ssid') || l.contains('password')) {
      return Icons.wifi_password_rounded;
    }
    if (l.contains('connection')) return Icons.wifi_rounded;
    if (l.contains('billing')) return Icons.receipt_long_rounded;
    if (l.contains('device') || l.contains('router') || l.contains('kit')) {
      return Icons.router_rounded;
    }
    if (l.contains('top') && l.contains('up')) return Icons.data_usage_rounded;
    if (l.contains('account')) return Icons.person_add_alt_1_rounded;
    if (l.contains('request')) return Icons.assignment_outlined;
    return Icons.label_outline_rounded;
  }

  /// Label above a field; [required] adds the red star.
  Widget _label(String text, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        FieldLabel(text),
        if (required)
          const Text(
            ' *',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.brand,
            ),
          ),
      ],
    ),
  );

  Widget _selectorTile({
    required String label,
    required String hint,
    required String? selectedLabel,
    required String? selectedSub,
    required bool hasError,
    required String errorText,
    required VoidCallback onTap,
  }) {
    final hasValue = selectedLabel != null && selectedLabel.isNotEmpty;
    final radius = BorderRadius.circular(AppRadius.lg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label, required: true),
        Material(
          color: AppColors.paper,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Container(
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: hasError ? AppColors.brand : AppColors.line,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          hasValue ? selectedLabel : hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                hasValue ? FontWeight.w500 : FontWeight.w400,
                            color: hasValue ? _ink : AppColors.inkFaint,
                          ),
                        ),
                        if (hasValue &&
                            selectedSub != null &&
                            selectedSub.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            selectedSub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: _inkSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _inkSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 4),
            child: Text(
              errorText,
              style: const TextStyle(
                color: AppColors.dangerInk,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  // ── Label / subtitle builders ──────────────────────────────────────────────

  String _ticketTypeLabel(Map<String, dynamic> item) =>
      ApiService.ticketTypeLabel(item);

  String _ticketTypeSub(Map<String, dynamic> item) =>
      item['description']?.toString() ?? '';

  String _contactLabel(Map<String, dynamic> item) {
    final label = item['label']?.toString() ?? '';
    if (label.isNotEmpty) return label;
    final name = item['name']?.toString() ?? '';
    if (name.isNotEmpty) return name;
    return item['email']?.toString() ?? '—';
  }

  String _contactSub(Map<String, dynamic> item) =>
      item['email']?.toString() ?? item['role']?.toString() ?? '';

  String _safeStr(Map<String, dynamic> item, String key) =>
      (item[key] == null ? '' : item[key].toString()).trim();

  String _subscriptionLabel(Map<String, dynamic> item) {
    final nickname = _safeStr(item, 'nickname');
    if (nickname.isNotEmpty) return nickname;
    final sln = _safeStr(item, 'service_line_number');
    if (sln.isNotEmpty) return sln;
    final plan =
        _safeStr(item, 'plan_name').isNotEmpty
            ? _safeStr(item, 'plan_name')
            : _safeStr(item, 'name');
    if (plan.isNotEmpty) return plan;
    final id = _safeStr(item, 'id');
    return id.isNotEmpty ? 'Subscription #$id' : '—';
  }

  String _subscriptionSub(Map<String, dynamic> item) {
    final parts = <String>[];
    final sln = _safeStr(item, 'service_line_number');
    final plan = _safeStr(item, 'plan_name');
    final status = _safeStr(item, 'status');
    if (sln.isNotEmpty) parts.add(sln);
    if (plan.isNotEmpty) parts.add(plan);
    if (status.isNotEmpty) parts.add(status.toUpperCase());
    return parts.join(' · ');
  }

  // ── File picker ────────────────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      setState(() {
        for (final f in result.files) {
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

  void _removeFile(int index) => setState(() => _pickedFiles.removeAt(index));

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

  // ── Submit ─────────────────────────────────────────────────────────────────

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

      final ticketTypeValue = ApiService.ticketTypeValue(_selectedTicketType!);
      if (ticketTypeValue.isEmpty) {
        setState(() => _typeError = true);
        _showError('Selected ticket type is invalid. Please re-select.');
        return;
      }

      final subscriptionId = _extractSubscriptionId(_selectedSubscription!);
      if (subscriptionId.isEmpty) {
        setState(() => _subscriptionError = true);
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

      final response = await _client
          .post(
            Uri.parse('${ApiService.baseUrl}/v1/tickets/'),
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

      if (_pickedFiles.isNotEmpty) {
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
            _showError(
              'Ticket created, but attachment upload failed: ${uploadResult['message']}',
            );
          }
        }
      }

      if (!mounted) return;
      AppToast.success(context, 'Ticket created successfully!');
      Navigator.pop(context, true);
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    AppToast.error(context, msg);
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────

  Widget _buildAttachmentsSection() {
    final radius = BorderRadius.circular(AppRadius.lg);
    return AppCard(
      child: Column(
        children: [
          Material(
            color: AppColors.paperSubtle,
            borderRadius: radius,
            child: InkWell(
              onTap: _pickFiles,
              borderRadius: radius,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: AppColors.line, width: 1.5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.upload_file_outlined, color: _primary, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add files',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Images, PDF, DOC, DOCX or TXT',
                            style: TextStyle(
                              color: _inkSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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

  // ── Build ──────────────────────────────────────────────────────────────────

  final _baseline = FormBaseline();
  bool get _hasChanges => _baseline.changed(
    ready: !_isLoadingData,
    values: [
      _subjectController.text,
      _descriptionController.text,
      _selectedTicketType,
      _selectedContact,
      _selectedSubscription,
    ],
  );

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      isDirty: () => _hasChanges,
      listenTo: Listenable.merge([_subjectController, _descriptionController]),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _surfaceSubtle,
          appBar: AppBar(title: const Text('New Ticket')),
          body:
              _isLoadingData
                  ? _buildLoading()
                  : _loadError != null
                  ? _buildErrorState()
                  : _buildForm(),
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
            style: const TextStyle(color: Color(0xFFE90408), fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadAllData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: const StadiumBorder(),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading('Ticket details'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _selectorTile(
                  label: 'Ticket type',
                  hint: 'Select ticket type',
                  selectedLabel:
                      _selectedTicketType != null
                          ? _ticketTypeLabel(_selectedTicketType!)
                          : null,
                  selectedSub:
                      _selectedTicketType != null
                          ? _ticketTypeSub(_selectedTicketType!)
                          : null,
                  hasError: _typeError,
                  errorText: 'Select a ticket type.',
                  onTap:
                      () => _showPicker<Map<String, dynamic>>(
                        title: 'Select Ticket Type',
                        items: _ticketTypes,
                        selected: _selectedTicketType,
                        labelBuilder: _ticketTypeLabel,
                        subtitleBuilder: _ticketTypeSub,
                        onSelect:
                            (v) => setState(() {
                              _selectedTicketType = v;
                              _typeError = false;
                            }),
                      ),
                ),
                const SizedBox(height: 14),
                _selectorTile(
                  label: 'Subscription',
                  hint: 'Select subscription',
                  selectedLabel:
                      _selectedSubscription != null
                          ? _subscriptionLabel(_selectedSubscription!)
                          : null,
                  selectedSub:
                      _selectedSubscription != null
                          ? _subscriptionSub(_selectedSubscription!)
                          : null,
                  hasError: _subscriptionError,
                  errorText: 'Select a subscription.',
                  onTap:
                      () => _showPicker<Map<String, dynamic>>(
                        title: 'Select Subscription',
                        items: _subscriptions,
                        selected: _selectedSubscription,
                        labelBuilder: _subscriptionLabel,
                        subtitleBuilder: _subscriptionSub,
                        onSelect:
                            (v) => setState(() {
                              _selectedSubscription = v;
                              _subscriptionError = false;
                            }),
                      ),
                ),
                const SizedBox(height: 14),
                _selectorTile(
                  label: 'Contact',
                  hint: 'Select contact',
                  selectedLabel:
                      _selectedContact != null
                          ? _contactLabel(_selectedContact!)
                          : null,
                  selectedSub:
                      _selectedContact != null
                          ? _contactSub(_selectedContact!)
                          : null,
                  hasError: _contactError,
                  errorText: 'Select a contact.',
                  onTap:
                      () => _showPicker<Map<String, dynamic>>(
                        title: 'Select Contact',
                        items: _contacts,
                        selected: _selectedContact,
                        labelBuilder: _contactLabel,
                        subtitleBuilder: _contactSub,
                        onSelect:
                            (v) => setState(() {
                              _selectedContact = v;
                              _contactError = false;
                            }),
                      ),
                ),
                const SizedBox(height: 14),
                _label('Subject (optional)'),
                TextField(
                  controller: _subjectController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: _ink, fontSize: 14),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'A short summary',
                  ),
                ),
                const SizedBox(height: 14),
                _label('Description', required: true),
                TextField(
                  controller: _descriptionController,
                  minLines: 4,
                  maxLines: 8,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) {
                    if (_descriptionError) {
                      setState(() => _descriptionError = false);
                    }
                  },
                  style: const TextStyle(color: _ink, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Describe the issue in detail',
                    errorText: _descriptionError ? 'Describe the issue.' : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeading('Attachments'),
          _buildAttachmentsSection(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitTicket,
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
                      : const Icon(Icons.send_rounded, size: 18),
              label: Text(_isSubmitting ? 'Submitting…' : 'Submit Ticket'),
            ),
          ),
        ],
      ),
    ),
  );
}
