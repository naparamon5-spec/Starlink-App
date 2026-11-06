import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:io';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/shared/widgets/app_version_label.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFF133341);
const _success = Color(0xFF10B981);
const _ink = Color(0xFF111111);
const _inkSecondary = Color(0xFF666666);
const _inkTertiary = Color(0xFF888888);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF8F8F8);
const _border = Color(0xFFD7D7D7);

class AdminEditProfilePage extends StatefulWidget {
  final String? bearerToken;
  const AdminEditProfilePage({super.key, this.bearerToken});

  @override
  State<AdminEditProfilePage> createState() => _AdminEditProfilePageState();
}

class _AdminEditProfilePageState extends State<AdminEditProfilePage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animController;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _positionController = TextEditingController();
  final _companyController = TextEditingController();
  final _codeController = TextEditingController();
  final _roleController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  Map<String, dynamic>? _profileData;
  String? _resolvedToken;

  http.Client get _httpClient {
    final httpClient =
        HttpClient()
          ..connectionTimeout = const Duration(seconds: 15)
          ..badCertificateCallback = (cert, host, port) => true;
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
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      _resolvedToken = widget.bearerToken;
      if (_resolvedToken == null || _resolvedToken!.isEmpty) {
        _resolvedToken = await ApiService.getValidAccessToken();
      }
      if (_resolvedToken == null || _resolvedToken!.isEmpty) {
        setState(() {
          _errorMessage = 'Session expired. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      final uri = Uri.parse('${ApiService.baseUrl}/v1/users/my/profile/');
      final response = await _httpClient
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $_resolvedToken',
            },
          )
          .timeout(const Duration(seconds: 15));

      final decoded = json.decode(response.body);

      if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
        final data = (decoded['data'] as Map<String, dynamic>?) ?? decoded;
        _profileData = data;
        _firstNameController.text = data['first_name']?.toString() ?? '';
        _lastNameController.text = data['last_name']?.toString() ?? '';
        _middleNameController.text = data['middle_name']?.toString() ?? '';
        _emailController.text = data['email']?.toString() ?? '';
        _positionController.text = data['position']?.toString() ?? '';
        _companyController.text = data['company_name']?.toString() ?? '';
        // First non-empty company/user code the profile has (admins may
        // have none, in which case the Code row is hidden).
        _codeController.text = [
              data['com_eu_code'],
              data['eu_code'],
              data['customer_code'],
              data['code'],
            ]
            .map((v) => v?.toString().trim() ?? '')
            .firstWhere((v) => v.isNotEmpty, orElse: () => '');
        _roleController.text = _capitalize(data['role']?.toString() ?? '');
        setState(() => _isLoading = false);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _animController.forward(),
        );
      } else if (response.statusCode == 401) {
        final refreshResult = await ApiService.refreshToken();
        if (refreshResult['status'] == 'success') {
          _resolvedToken = refreshResult['accessToken']?.toString();
          await _loadProfile();
        } else {
          await ApiService.clearTokens();
          setState(() {
            _errorMessage = 'Session expired. Please log in again.';
            _isLoading = false;
          });
        }
      } else {
        final msg = decoded is Map ? decoded['message']?.toString() : null;
        setState(() {
          _errorMessage = msg ?? 'Server error ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  @override
  void dispose() {
    _animController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleNameController.dispose();
    _emailController.dispose();
    _positionController.dispose();
    _companyController.dispose();
    _codeController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    var userId = _profileData?['id']?.toString() ?? '';
    if (userId.isEmpty) {
      final me = await ApiService.getMe();
      final data = me['data'];
      final user = data is Map && data['user'] is Map ? data['user'] : data;
      if (user is Map) userId = user['id']?.toString() ?? '';
    }
    if (!mounted) return;
    if (userId.isEmpty) {
      _showSnack('User ID not found. Please log out and back in.', true);
      return;
    }

    setState(() => _isSaving = true);
    final res = await ApiService.updateUser(userId, {
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'middle_name': _middleNameController.text.trim(),
      'position': _positionController.text.trim(),
    });
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res['status'] == 'success') {
      _showSnack('Profile updated successfully', false);
      Navigator.pop(context, true);
    } else {
      _showSnack(
        res['message']?.toString() ?? 'Failed to update profile.',
        true,
      );
    }
  }

  void _showSnack(String msg, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? _primary : _success,
        content: Text(msg),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 2),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          t,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _primary,
            letterSpacing: 1.1,
          ),
        ),
      ],
    ),
  );

  /// Labeled field (label stays above the value so read-only rows like
  /// Code and Role are self-explanatory).
  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    bool readOnly = false,
  }) => Container(
    decoration: BoxDecoration(
      color: readOnly ? _surfaceSubtle : _surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border, width: 1.5),
    ),
    child: TextFormField(
      controller: c,
      readOnly: readOnly,
      style: TextStyle(
        color: readOnly ? _inkSecondary : _ink,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(
          icon,
          size: 18,
          color: readOnly ? _inkTertiary : _primary,
        ),
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(
          color: _inkTertiary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: _inkTertiary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        hintText: readOnly ? '—' : 'Enter ${label.toLowerCase()}',
        hintStyle: const TextStyle(color: _inkTertiary, fontSize: 14),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      ),
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFEDF1F5)),
      boxShadow: [
        BoxShadow(
          blurRadius: 18,
          color: const Color(0xFF133341).withOpacity(0.06),
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _surfaceSubtle,
        // ── Custom AppBar inside body so gradient extends under status bar ──
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              // ── Gradient AppBar ──────────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF133341), Color(0xFF0C2029)],
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
                          child: Text(
                            'Edit Profile',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 52),
                        // if (!_isLoading && _errorMessage == null)
                        //   TextButton(
                        //     onPressed: _saveProfile,
                        //     style: TextButton.styleFrom(
                        //       backgroundColor: Colors.white.withOpacity(0.15),
                        //       shape: RoundedRectangleBorder(
                        //         borderRadius: BorderRadius.circular(10),
                        //       ),
                        //       padding: const EdgeInsets.symmetric(
                        //         horizontal: 14,
                        //         vertical: 8,
                        //       ),
                        //     ),
                        //     child: const Text(
                        //       'Save',
                        //       style: TextStyle(
                        //         color: Colors.white,
                        //         fontWeight: FontWeight.w700,
                        //         fontSize: 13,
                        //       ),
                        //     ),
                        //   ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Body ────────────────────────────────────────────────────
              Expanded(
                child:
                    _isLoading
                        ? const Center(
                          child: CircularProgressIndicator(color: _primary),
                        )
                        : _errorMessage != null
                        ? _buildError()
                        : _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
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
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFE90408), fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadProfile,
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

  Widget _buildContent() => AnimatedBuilder(
    animation: _animController,
    builder:
        (context, child) => Opacity(
          opacity: _animController.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _animController.value)),
            child: child,
          ),
        ),
    child: Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('PERSONAL INFORMATION'),
            _card(
              child: Column(
                children: [
                  _field(
                    _firstNameController,
                    'First Name',
                    Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _lastNameController,
                    'Last Name',
                    Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _middleNameController,
                    'Middle Name',
                    Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  _field(
                    _emailController,
                    'Email Address',
                    Icons.email_outlined,
                    readOnly: true,
                  ),
                  const SizedBox(height: 12),
                  _field(_positionController, 'Position', Icons.work_outline),
                ],
              ),
            ),

            const SizedBox(height: 22),

            _sectionTitle('ORGANIZATION'),
            _card(
              child: Column(
                children: [
                  _field(
                    _companyController,
                    'Company',
                    Icons.business_outlined,
                    readOnly: true,
                  ),
                  if (_codeController.text.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _field(
                      _codeController,
                      'Code',
                      Icons.tag_rounded,
                      readOnly: true,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _field(
                    _roleController,
                    'Role',
                    Icons.shield_outlined,
                    readOnly: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            const SizedBox(height: 22),

            // _sectionTitle('PREFERENCES'),
            // _card(
            //   child: SwitchListTile(
            //     value: _notificationsEnabled,
            //     activeThumbColor: _primary,
            //     title: const Text(
            //       'Email Notifications',
            //       style: TextStyle(
            //         fontSize: 14,
            //         fontWeight: FontWeight.w600,
            //         color: _ink,
            //       ),
            //     ),
            //     subtitle: const Text(
            //       'Receive updates via email',
            //       style: TextStyle(fontSize: 12, color: _inkSecondary),
            //     ),
            //     onChanged: (v) => setState(() => _notificationsEnabled = v),
            //   ),
            // ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                ),
                child:
                    _isSaving
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
              ),
            ),

            const SizedBox(height: 24),
            const AppVersionLabel(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

// ── Dialog Field ──────────────────────────────────────────────────────────────
