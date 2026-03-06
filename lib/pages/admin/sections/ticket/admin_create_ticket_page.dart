import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
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

/// Explicit dark style used on every DropdownMenuItem child.
/// This is the fix for white-on-white text — Flutter's DropdownButtonFormField
/// does NOT inherit the `style` property into its overlay menu items, so each
/// item's Text widget must carry its own TextStyle.
const _dropItemStyle = TextStyle(
  color: _ink,
  fontSize: 14,
  fontWeight: FontWeight.w500,
);

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
        // 0 — subscriptions (paginated endpoint so we get nickname)
        _client
            .get(
              Uri.parse(
                '$_baseUrl/api/v1/subscriptions/paginated?page=1&limit=200',
              ),
              headers: headers,
            )
            .timeout(const Duration(seconds: 20)),
        // 1 — ticket categories
        _client
            .get(
              Uri.parse('$_baseUrl/api/v1/tickets/list/categories'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 20)),
        // 2 — contacts (returns { data: [ { value, label } ] })
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
        // ── Subscriptions ──────────────────────────────────────────────────
        if (results[0].statusCode == 200) {
          // paginated endpoint wraps items under data.data
          dynamic raw = subsBody['data'];
          if (raw is Map) raw = raw['data'] ?? raw;
          _subscriptions = _asList(raw);
        }

        // ── Ticket types ───────────────────────────────────────────────────
        if (results[1].statusCode == 200) {
          final raw = typesBody['data'] ?? typesBody['results'] ?? typesBody;
          _ticketTypes = _asList(raw);
        }

        // ── Contacts ───────────────────────────────────────────────────────
        // API shape: { "data": [ { "value": 10, "label": "Name" } ], ... }
        if (results[2].statusCode == 200) {
          final raw =
              contactBody['data'] ?? contactBody['results'] ?? contactBody;
          // Normalise to always have both `value` (int id) and `label` (name)
          _contacts =
              _asList(raw).map((e) {
                return <String, dynamic>{
                  'value': e['value'] ?? e['id'],
                  'label': (e['label'] ?? e['name'] ?? '').toString(),
                  // keep original keys too, for submit
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

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submitTicket() async {
    setState(() {
      _typeError = _selectedTicketType == null;
      _contactError = _selectedContact == null;
      _subscriptionError = _selectedSubscription == null;
      _descriptionError = _descriptionController.text.trim().isEmpty;
    });

    if (_typeError || _contactError || _subscriptionError || _descriptionError)
      return;

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

      final subscriptionId =
          _selectedSubscription!['id']?.toString() ??
          _selectedSubscription!['subscription_id']?.toString() ??
          '';

      // Use `value` (int ID) from the contact — that's what the API returns
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

      if (response.statusCode == 200 || response.statusCode == 201) {
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
      } else {
        final msg =
            decoded is Map
                ? (decoded['message'] ??
                    decoded['detail'] ??
                    'Failed to create ticket.')
                : 'Failed to create ticket.';
        _showError(msg.toString());
      }
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

  /// ─── THE FIX ───────────────────────────────────────────────────────────────
  /// Flutter's DropdownButtonFormField renders menu items in a separate overlay
  /// that does NOT inherit the widget-level `style`. To prevent white text on a
  /// white/light background every DropdownMenuItem's child Text must carry an
  /// explicit TextStyle with a dark color.
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
            value: value,
            isExpanded: true,
            // ✅ style only affects the selected-value display inside the field
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
                      // ✅ explicit dark style so menu items are visible on white
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
              if (hasError)
                setState(() {
                  if (c == _descriptionController) _descriptionError = false;
                });
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

  /// Contact API returns { "value": int, "label": "Name" }
  /// Always prefer `label`; fall back to name/email.
  String _contactLabel(Map<String, dynamic> item) {
    final label = item['label']?.toString() ?? '';
    if (label.isNotEmpty) return label;
    final name = item['name']?.toString() ?? '';
    final email = item['email']?.toString() ?? '';
    if (name.isNotEmpty && email.isNotEmpty) return '$name ($email)';
    return name.isNotEmpty ? name : (email.isNotEmpty ? email : '—');
  }

  /// Subscription: show `nickname` first, then fall back gracefully.
  String _subscriptionLabel(Map<String, dynamic> item) {
    final nickname = item['nickname']?.toString().trim() ?? '';
    if (nickname.isNotEmpty) return nickname;

    final sln = item['service_line_number']?.toString().trim() ?? '';
    if (sln.isNotEmpty) {
      final plan = item['plan_name']?.toString().trim() ?? '';
      return plan.isNotEmpty ? '$sln – $plan' : sln;
    }

    final plan =
        item['plan_name']?.toString().trim() ??
        item['name']?.toString().trim() ??
        item['subscription_name']?.toString().trim() ??
        '';
    if (plan.isNotEmpty) return plan;

    final id = item['id']?.toString() ?? '';
    return id.isNotEmpty ? 'Subscription #$id' : '—';
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
                  // Uses `label` key from the API { value, label } shape
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

          // Subscription — shows nickname
          _sectionLabel('SUBSCRIPTION'),
          _card(
            child: _dropdown<Map<String, dynamic>>(
              hint: 'Select Subscription',
              icon: Icons.router_outlined,
              items: _subscriptions,
              value: _selectedSubscription,
              // Uses `nickname` as primary label
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
                      if (_descriptionError)
                        setState(() => _descriptionError = false);
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
          _card(
            child: Column(
              children: [
                Container(
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
                        'Drag and drop file here to upload',
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
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {},
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
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
