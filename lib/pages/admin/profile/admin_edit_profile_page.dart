import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:io';
import '../../../services/api_service.dart';
import '../../change-password.dart';

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
  final _roleController = TextEditingController();

  bool _notificationsEnabled = true;
  bool _twoFactorEnabled = false;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _profileData;
  String? _resolvedToken;

  String get _initials {
    final f = _firstNameController.text.trim();
    final l = _lastNameController.text.trim();
    if (f.isEmpty && l.isEmpty) return '?';
    return '${f.isNotEmpty ? f[0].toUpperCase() : ''}${l.isNotEmpty ? l[0].toUpperCase() : ''}';
  }

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

      final uri = Uri.parse(
        'https://starlink-api.ardentnetworks.com.ph/api/v1/users/my/profile/',
      );
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
    _roleController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _success,
          content: Text('Profile updated successfully'),
        ),
      );
      Navigator.pop(context);
    }
  }

  void _changePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminChangePasswordPage()),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
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

  Widget _field(
    TextEditingController c,
    String hint,
    IconData icon, {
    bool readOnly = false,
  }) => Container(
    decoration: BoxDecoration(
      color: readOnly ? const Color(0xFFF0F0F0) : _surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: TextFormField(
      controller: c,
      readOnly: readOnly,
      style: TextStyle(color: readOnly ? _inkSecondary : _ink, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(
          icon,
          size: 18,
          color: readOnly ? _inkTertiary : _primary,
        ),
        hintText: hint,
        hintStyle: const TextStyle(color: _inkTertiary, fontSize: 14),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
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
          blurRadius: 8,
          color: Colors.black.withOpacity(.04),
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );

  Widget _chip(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: _primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _primary.withOpacity(0.2)),
    ),
    child: Text(
      '$label: $value',
      style: const TextStyle(
        fontSize: 12,
        color: _primary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _avatar() => Center(
    child: Stack(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEB1E23), Color(0xFF760F12)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _primaryDark.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: Text(
              _initials,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: _border, width: 2),
            ),
            // child: IconButton(
            //   icon: const Icon(Icons.camera_alt, size: 16, color: _primary),
            //   onPressed: () {},
            //   constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            //   padding: const EdgeInsets.all(6),
            // ),
          ),
        ),
      ],
    ),
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
                          child: Text(
                            'Edit Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
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
            style: const TextStyle(color: _inkSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadProfile,
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
            // Avatar + chips
            _avatar(),
            const SizedBox(height: 14),
            Center(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (_profileData?['role'] != null)
                    _chip(
                      'Role',
                      _capitalize(_profileData!['role'].toString()),
                    ),
                  if (_profileData?['com_eu_code'] != null)
                    _chip('Code', _profileData!['com_eu_code'].toString()),
                ],
              ),
            ),

            const SizedBox(height: 28),

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

            _sectionTitle('SECURITY'),
            _card(
              child: Column(
                children: [
                  // SwitchListTile(
                  //   value: _twoFactorEnabled,
                  //   activeThumbColor: _primary,
                  //   title: const Text(
                  //     'Two-Factor Authentication',
                  //     style: TextStyle(
                  //       fontSize: 14,
                  //       fontWeight: FontWeight.w600,
                  //       color: _ink,
                  //     ),
                  //   ),
                  //   subtitle: const Text(
                  //     'Add extra security to your account',
                  //     style: TextStyle(fontSize: 12, color: _inkSecondary),
                  //   ),
                  //   onChanged: (v) => setState(() => _twoFactorEnabled = v),
                  // ),
                  // Divider(color: _border, height: 1),
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        color: _primary,
                        size: 18,
                      ),
                    ),
                    title: const Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: _inkTertiary,
                    ),
                    onTap: _changePassword,
                  ),
                ],
              ),
            ),

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
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Dialog Field ──────────────────────────────────────────────────────────────

class _DialogField extends StatelessWidget {
  final String label;
  final String hint;
  const _DialogField({required this.label, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _inkSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: _surfaceSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: TextField(
            obscureText: true,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: _inkTertiary),
              prefixIcon: const Icon(
                Icons.lock_outline,
                size: 18,
                color: _inkTertiary,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
