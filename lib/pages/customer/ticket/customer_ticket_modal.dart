import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../../../services/api_service.dart';
import '../../../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────

class CustomerTicketModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onConfirm;
  final VoidCallback? onCancel;
  final int userId;

  const CustomerTicketModal({
    super.key,
    required this.onConfirm,
    this.onCancel,
    required this.userId,
  });

  @override
  _CustomerTicketModalState createState() => _CustomerTicketModalState();
}

class _CustomerTicketModalState extends State<CustomerTicketModal>
    with SingleTickerProviderStateMixin {
  // ── Form ──────────────────────────────────────────────────────────────────
  final _descriptionController = TextEditingController();

  Map<String, dynamic>? _selectedTicketType;
  Map<String, dynamic>? _selectedContact;
  Map<String, dynamic>? _selectedSubscription;

  // ── API data ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _ticketTypes = [];
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _subscriptions = [];

  // ── Attachments ───────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _pickedFiles = [];

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isLoadingData = true;
  bool _isSubmitting = false;
  String? _loadError;

  bool _typeError = false;
  bool _contactError = false;
  bool _subscriptionError = false;
  bool _descriptionError = false;

  late AnimationController _animController;

  // ── Customer codes ────────────────────────────────────────────────────────
  String? _euCode;
  String? _customerCode;
  String? _userRole;

  // ── HTTP client ───────────────────────────────────────────────────────────
  static const _baseUrl = 'https://starlink-api.ardentnetworks.com.ph';

  http.Client get _client {
    final httpClient =
        HttpClient()
          ..connectionTimeout = const Duration(seconds: 20)
          ..badCertificateCallback = (cert, host, port) => true;
    return IOClient(httpClient);
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadAllData();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async => await ApiService.getValidAccessToken();

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _asList(dynamic raw) {
    if (raw is List) return raw.whereType<Map<String, dynamic>>().toList();
    if (raw is Map<String, dynamic>) return [raw];
    return [];
  }

  String _firstNonEmpty(Iterable<dynamic> values) {
    for (final v in values) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
    }
    return '';
  }

  String _extractSubscriptionId(Map<String, dynamic> sub) => _firstNonEmpty([
    sub['service_line_number'],
    sub['serviceLineNumber'],
    sub['serviceLine'],
    sub['subscription_id'],
    sub['subscriptionId'],
    sub['id'],
  ]);

  int? _extractContactUserId(Map<String, dynamic> contact) {
    final candidates = [
      contact['user_id'],
      contact['userId'],
      contact['value'],
      contact['id'],
      contact['contact_id'],
      contact['contactId'],
    ];

    for (final candidate in candidates) {
      if (candidate is int) return candidate;
      final parsed = int.tryParse(candidate?.toString() ?? '');
      if (parsed != null) return parsed;
    }

    return null;
  }

  Future<void> _createAssignedContactNotification({
    required String ticketId,
    required String ticketType,
    required String contactName,
    required String description,
  }) async {
    final selectedContact = _selectedContact;
    if (selectedContact == null) return;

    final contactUserId = _extractContactUserId(selectedContact);
    if (contactUserId == null) return;

    final trimmedDescription = description.trim();
    final shortDescription =
        trimmedDescription.length > 120
            ? '${trimmedDescription.substring(0, 120)}...'
            : trimmedDescription;

    try {
      await NotificationService.createCustomerNotification({
        'user_id': contactUserId,
        'title': 'New Ticket Assigned',
        'message':
            'You have been selected as contact for Ticket #$ticketId ($ticketType). ${shortDescription.isEmpty ? '' : shortDescription}',
        'type': 'ticket_assigned',
        'icon': 'confirmation_number',
        'color': '#EB1E23',
        'reference_id': ticketId,
        'is_read': 0,
        'data': {
          'ticket_id': ticketId,
          'ticket_type': ticketType,
          'contact_name': contactName,
          'description': trimmedDescription,
        },
      });
    } catch (e) {
      debugPrint('Failed to create assigned contact notification: $e');
    }
  }

  int? _extractNotificationUserId(Map<String, dynamic> item) {
    final candidates = [
      item['user_id'],
      item['userId'],
      item['id'],
      item['value'],
      item['contact_id'],
      item['contactId'],
    ];
    for (final candidate in candidates) {
      if (candidate is int) return candidate;
      final parsed = int.tryParse(candidate?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  String _ticketSubjectForNotification() {
    final ticketType =
        _selectedTicketType == null
            ? ''
            : _ticketTypeLabel(_selectedTicketType!);
    if (ticketType.isNotEmpty && ticketType != '—') return ticketType;
    return 'New Ticket';
  }

  Future<void> _notifySelectedContact({
    required String ticketId,
    required String contactValue,
    required String subscriptionId,
  }) async {
    if (_selectedContact == null) return;

    final selectedUserId = _extractNotificationUserId(_selectedContact!);
    if (selectedUserId == null) return;

    final selectedLabel = _contactLabel(_selectedContact!);
    final createdByName = _firstNonEmpty([
      (await ApiService.getMe())['data']?['name'],
      (await ApiService.getMe())['data']?['full_name'],
      (await ApiService.getMe())['data']?['username'],
      'A customer',
    ]);

    await NotificationService.createCustomerNotification({
      'user_id': selectedUserId,
      'title': 'New Ticket Assigned',
      'message':
          '$createdByName created ticket #$ticketId and selected you as contact for ${_ticketSubjectForNotification()}.',
      'type': 'ticket_created',
      'icon': 'confirmation_number',
      'color': '#EB1E23',
      'is_read': 0,
      'data': {
        'ticket_id': ticketId,
        'ticket_type': _ticketSubjectForNotification(),
        'subscription_id': subscriptionId,
        'contact': contactValue,
        'contact_name': selectedLabel,
        'created_by': createdByName,
        'description': _descriptionController.text.trim(),
      },
    });
  }

  // ── Load subscriptions with multiple fallback strategies ──────────────────

  Future<List<Map<String, dynamic>>> _fetchSubscriptions(String token) async {
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    if (_euCode != null && _euCode!.isNotEmpty) {
      try {
        final r = await _client
            .get(
              Uri.parse('$_baseUrl/api/v1/subscriptions/end-user/$_euCode'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 20));
        final list = _parseSubscriptionResponse(r);
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }

    if (_customerCode != null && _customerCode!.isNotEmpty) {
      try {
        final r = await _client
            .get(
              Uri.parse(
                '$_baseUrl/api/v1/subscriptions/customer/$_customerCode',
              ),
              headers: headers,
            )
            .timeout(const Duration(seconds: 20));
        final list = _parseSubscriptionResponse(r);
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }

    try {
      final r = await _client
          .get(
            Uri.parse(
              '$_baseUrl/api/v1/subscriptions/paginated?page=1&limit=500',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));
      final list = _parseSubscriptionResponse(r);
      if (list.isNotEmpty) return list;
    } catch (_) {}

    try {
      final r = await _client
          .get(Uri.parse('$_baseUrl/api/v1/subscriptions/'), headers: headers)
          .timeout(const Duration(seconds: 30));
      final list = _parseSubscriptionResponse(r);
      if (list.isNotEmpty) return list;
    } catch (_) {}

    return [];
  }

  List<Map<String, dynamic>> _parseSubscriptionResponse(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) return [];
    try {
      final decoded = json.decode(r.body);
      return _extractListFromDecoded(decoded);
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _extractListFromDecoded(dynamic decoded) {
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().map((item) {
        return Map<String, dynamic>.fromEntries(
          item.entries.map((e) => MapEntry(e.key, e.value ?? '')),
        );
      }).toList();
    }

    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().map((item) {
          return Map<String, dynamic>.fromEntries(
            item.entries.map((e) => MapEntry(e.key, e.value ?? '')),
          );
        }).toList();
      }
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is List) {
          return inner.whereType<Map<String, dynamic>>().map((item) {
            return Map<String, dynamic>.fromEntries(
              item.entries.map((e) => MapEntry(e.key, e.value ?? '')),
            );
          }).toList();
        }
      }
    }

    return [];
  }

  // ── Load all data ─────────────────────────────────────────────────────────

  Future<void> _loadAllData() async {
    setState(() {
      _isLoadingData = true;
      _loadError = null;
    });

    try {
      await _loadCustomerCodes();

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

      final parallelResults = await Future.wait([
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

      final typesBody = json.decode(parallelResults[0].body);
      final contactBody = json.decode(parallelResults[1].body);

      final subscriptions = await _fetchSubscriptions(token);

      setState(() {
        if (parallelResults[0].statusCode == 200) {
          final raw = typesBody['data'] ?? typesBody['results'] ?? typesBody;
          _ticketTypes = _asList(raw);
        }

        if (parallelResults[1].statusCode == 200) {
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

        _subscriptions = subscriptions;
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

  Future<void> _loadCustomerCodes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _euCode = prefs.getString('eu_code');
      _customerCode =
          prefs.getString('customer_code') ?? prefs.getString('com_eu_code');
      _userRole = prefs.getString('user_role') ?? prefs.getString('role');

      final profile = await ApiService.getMe();
      if (profile['status'] == 'success' && profile['data'] != null) {
        final data = profile['data'] as Map<String, dynamic>;
        _euCode =
            data['eu_code']?.toString() ??
            data['euCode']?.toString() ??
            _euCode;
        _customerCode =
            data['customer_code']?.toString() ??
            data['com_eu_code']?.toString() ??
            data['customerCode']?.toString() ??
            _customerCode;
        _userRole =
            data['role']?.toString() ??
            data['user_role']?.toString() ??
            data['type']?.toString() ??
            _userRole;

        if (_euCode != null) await prefs.setString('eu_code', _euCode!);
        if (_customerCode != null) {
          await prefs.setString('customer_code', _customerCode!);
        }
        if (_userRole != null) {
          await prefs.setString('user_role', _userRole!);
        }
      }
    } catch (e) {
      debugPrint('Error loading customer codes: $e');
    }
  }

  // ── Bottom-sheet picker (matches admin design) ────────────────────────────

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

                  // Title + close
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
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
                        color: _surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: TextField(
                        controller: searchController,
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
                  const SizedBox(height: 8),
                  Container(height: 1, color: _border),

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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 13,
                                    ),
                                    color:
                                        isSelected
                                            ? _primary.withOpacity(0.05)
                                            : Colors.transparent,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color:
                                                isSelected
                                                    ? _primary.withOpacity(0.12)
                                                    : _surfaceSubtle,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              label.isNotEmpty
                                                  ? label[0].toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    isSelected
                                                        ? _primary
                                                        : _inkTertiary,
                                              ),
                                            ),
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
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: _primary,
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

  // ── Tap-to-open selector tile (matches admin _selectorTile) ──────────────

  Widget _selectorTile({
    required String hint,
    required IconData icon,
    required String? selectedLabel,
    required String? selectedSub,
    required bool hasError,
    required String errorText,
    required VoidCallback onTap,
  }) {
    final hasValue = selectedLabel != null && selectedLabel.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: _surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError ? _errorColor : _border,
                width: hasError ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: hasError ? _errorColor : _primary),
                const SizedBox(width: 10),
                Expanded(
                  child:
                      hasValue
                          ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedLabel,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _ink,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (selectedSub != null &&
                                  selectedSub.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  selectedSub,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _inkTertiary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          )
                          : Text(
                            hint,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  hasError
                                      ? _errorColor.withOpacity(0.7)
                                      : _inkTertiary,
                            ),
                          ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: hasError ? _errorColor : _inkTertiary,
                  size: 20,
                ),
              ],
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

  // ── Submit ────────────────────────────────────────────────────────────────

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
        setState(() => _subscriptionError = true);
        _showError('Selected subscription is invalid. Please re-select.');
        setState(() => _isSubmitting = false);
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
      });

      final httpClient =
          HttpClient()
            ..connectionTimeout = const Duration(seconds: 20)
            ..badCertificateCallback = (cert, host, port) => true;
      final client = IOClient(httpClient);

      final response = await client
          .post(
            Uri.parse('$_baseUrl/api/v1/tickets/'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));

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
        try {
          await _notifySelectedContact(
            ticketId: ticketId,
            contactValue: contactValue,
            subscriptionId: subscriptionId,
          );
        } catch (e) {
          debugPrint('Failed to notify selected contact: $e');
        }
      }

      List<Map<String, dynamic>> uploadedAttachmentMeta = [];

      if (_pickedFiles.isNotEmpty && ticketId.isNotEmpty) {
        final uploadResult = await ApiService.uploadAttachments(
          ticketId: ticketId,
          files: _pickedFiles,
          bearerToken: token,
        );
        if (uploadResult['status'] != 'success') {
          _showError(
            'Ticket created, but attachment upload failed: ${uploadResult['message']}',
          );
        } else {
          final dynamic data = uploadResult['data'];
          if (data is List) {
            uploadedAttachmentMeta =
                data
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();
          } else if (data is Map) {
            final dynamic inner = data['data'] ?? data['attachments'];
            if (inner is List) {
              uploadedAttachmentMeta =
                  inner
                      .whereType<Map>()
                      .map((e) => Map<String, dynamic>.from(e))
                      .toList();
            }
          }

          if (uploadedAttachmentMeta.isEmpty) {
            uploadedAttachmentMeta =
                _pickedFiles
                    .map(
                      (f) => <String, dynamic>{
                        'name': f['name'],
                        'size': _formatFileSize(f['size'] as int),
                      },
                    )
                    .toList();
          }
        }
      }

      if (!mounted) return;

      await _createAssignedContactNotification(
        ticketId: ticketId.isEmpty ? 'new' : ticketId,
        ticketType: ticketTypeValue,
        contactName: _contactLabel(_selectedContact!),
        description: _descriptionController.text.trim(),
      );

      final formattedTicket = <String, dynamic>{
        'id': ticketId,
        'Status': 'OPEN',
        'Ticket Type': ticketTypeValue,
        'Contact': _contactLabel(_selectedContact!),
        'Subscription': _subscriptionLabel(_selectedSubscription!),
        'Description': _descriptionController.text.trim(),
        'Created At': DateTime.now().toString(),
        'Attachments':
            uploadedAttachmentMeta.isNotEmpty
                ? uploadedAttachmentMeta
                    .map((f) => f['name']?.toString() ?? '')
                    .where((n) => n.isNotEmpty)
                    .join(', ')
                : 'No attachments',
        'full_data': {
          'id': ticketId,
          'status': 'OPEN',
          'ticket_type': ticketTypeValue,
          'type': ticketTypeValue,
          'contact': contactValue,
          'contact_name': _contactLabel(_selectedContact!),
          'subscription': _subscriptionLabel(_selectedSubscription!),
          'subscription_id': subscriptionId,
          'description': _descriptionController.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
          'attachments': uploadedAttachmentMeta,
          'user_id': widget.userId,
        },
        'forceRefresh': true,
      };

      widget.onConfirm(formattedTicket);
      Navigator.of(context).pop(formattedTicket);
    } catch (e) {
      if (mounted) {
        _showError(
          'Error creating ticket: ${e.toString().replaceAll("Exception: ", "")}',
        );
      }
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

  // ── File picker ───────────────────────────────────────────────────────────

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

  // ── Label builders ────────────────────────────────────────────────────────

  String _ticketTypeLabel(Map<String, dynamic> item) =>
      item['name']?.toString() ??
      item['category']?.toString() ??
      item['label']?.toString() ??
      '—';

  String _ticketTypeSub(Map<String, dynamic> item) =>
      item['description']?.toString() ?? '';

  String _contactLabel(Map<String, dynamic> item) {
    final label = item['label']?.toString() ?? '';
    if (label.isNotEmpty) return label;
    final name = item['name']?.toString() ?? '';
    final email = item['email']?.toString() ?? '';
    if (name.isNotEmpty && email.isNotEmpty) return '$name ($email)';
    return name.isNotEmpty ? name : (email.isNotEmpty ? email : '—');
  }

  String _contactSub(Map<String, dynamic> item) =>
      item['email']?.toString() ?? item['role']?.toString() ?? '';

  String _safeStr(Map<String, dynamic> item, String key) =>
      (item[key] == null ? '' : item[key].toString()).trim();

  String _subscriptionLabel(Map<String, dynamic> item) {
    final nickname = _safeStr(item, 'nickname');
    if (nickname.isNotEmpty) return nickname;
    final sln =
        _safeStr(item, 'service_line_number').isNotEmpty
            ? _safeStr(item, 'service_line_number')
            : _safeStr(item, 'serviceLineNumber');
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

  // ── UI helpers ────────────────────────────────────────────────────────────

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

  Widget _buildAttachmentsSection() => _card(
    child: Column(
      children: [
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

  // ── Main build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.95,
        decoration: const BoxDecoration(
          color: _surfaceSubtle,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Gradient header ────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEB1E23), Color(0xFF760F12)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed:
                            widget.onCancel ??
                            () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 22,
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

            // ── Body ──────────────────────────────────────────────────────
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
          'Fetching categories, contacts & subscriptions',
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

  Widget _buildForm() {
    final showSubWarning = _subscriptions.isEmpty;

    return AnimatedBuilder(
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
            // ── Ticket Details ─────────────────────────────────────────────
            _sectionLabel('TICKET DETAILS'),
            _card(
              child: Column(
                children: [
                  // Ticket Type picker
                  _selectorTile(
                    hint: 'Select Ticket Type',
                    icon: Icons.confirmation_number_outlined,
                    selectedLabel:
                        _selectedTicketType != null
                            ? _ticketTypeLabel(_selectedTicketType!)
                            : null,
                    selectedSub:
                        _selectedTicketType != null
                            ? _ticketTypeSub(_selectedTicketType!)
                            : null,
                    hasError: _typeError,
                    errorText: 'Ticket type is required',
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
                  // Contact picker
                  _selectorTile(
                    hint: 'Select Contact',
                    icon: Icons.person_outline,
                    selectedLabel:
                        _selectedContact != null
                            ? _contactLabel(_selectedContact!)
                            : null,
                    selectedSub:
                        _selectedContact != null
                            ? _contactSub(_selectedContact!)
                            : null,
                    hasError: _contactError,
                    errorText: 'Contact is required',
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
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Subscription ───────────────────────────────────────────────
            _sectionLabel('SUBSCRIPTION'),
            if (showSubWarning)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No subscriptions found. Please contact your administrator.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadAllData,
                        child: Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            _card(
              child: _selectorTile(
                hint: 'Select Subscription',
                icon: Icons.router_outlined,
                selectedLabel:
                    _selectedSubscription != null
                        ? _subscriptionLabel(_selectedSubscription!)
                        : null,
                selectedSub:
                    _selectedSubscription != null
                        ? _subscriptionSub(_selectedSubscription!)
                        : null,
                hasError: _subscriptionError,
                errorText: 'Subscription is required',
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
            ),
            const SizedBox(height: 20),

            // ── Description ────────────────────────────────────────────────
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
                          Icon(
                            Icons.error_outline,
                            size: 14,
                            color: _errorColor,
                          ),
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

            // ── Attachments ────────────────────────────────────────────────
            _sectionLabel('ATTACHMENTS'),
            _buildAttachmentsSection(),
            const SizedBox(height: 28),

            // ── Action buttons ─────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _isSubmitting
                            ? null
                            : (widget.onCancel ??
                                () => Navigator.of(context).pop()),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
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
                      _isSubmitting ? 'Submitting...' : 'Create Ticket',
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
}
