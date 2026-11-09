import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/shared/widgets/unsaved_changes_guard.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/features/auth/login_screen.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/features/auth/two_factor/two_factor_settings_card.dart';
import 'package:starlink_app/features/security/biometric_settings_card.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFF133341);
const _ink = Color(0xFF111111);
const _inkSecondary = Color(0xFF666666);
const _inkTertiary = Color(0xFF888888);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF8F8F8);
const _border = Color(0xFFD7D7D7);
const _danger = Color(0xFFE90408);

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animController;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSaving = false;
  String? _currentPasswordError;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      value: 1.0,
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _animController.forward(),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  void _saveSecuritySettings() async {
    setState(() => _currentPasswordError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      // Calls PUT /api/v1/auth/change-password with Bearer token auth
      final response = await ApiService.changePassword(
        oldPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      if (response['status'] == 'success') {
        AppToast.success(context, 'Password changed. Please sign in again.');
Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
      } else {
        final msg =
            response['message']?.toString() ?? 'Failed to update password.';
        final l = msg.toLowerCase();
        if (l.contains('current') ||
            l.contains('old') ||
            l.contains('incorrect')) {
          setState(() => _currentPasswordError = msg);
        } else {
          _showSnack(msg, isError: true);
        }
      }
    } catch (_) {
      _showSnack('An error occurred. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    AppToast.result(context, msg, ok: !isError);
  }

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

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String)? extraValidator,
    String? errorText,
    VoidCallback? onChanged,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: _ink, fontSize: 14),
      onChanged: onChanged == null ? null : (_) => onChanged(),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        prefixIcon: const Icon(Icons.lock_outline, size: 18, color: _primary),
        hintText: hint,
        hintStyle: const TextStyle(color: _inkTertiary, fontSize: 14),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 18,
            color: _inkTertiary,
          ),
          onPressed: onToggleVisibility,
        ),
        errorText: errorText,
        errorMaxLines: 2,
        errorStyle: const TextStyle(color: _danger, fontSize: 12),
        enabledBorder: border(const Color(0xFFE2E8F0)),
        focusedBorder: border(_primary, 1.5),
        errorBorder: border(_danger),
        focusedErrorBorder: border(_danger, 1.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) {
          final name = hint.toLowerCase();
          return '${name[0].toUpperCase()}${name.substring(1)} is required';
        }
        if (v.length < 6) return 'Password must be at least 6 characters';
        return extraValidator?.call(v);
      },
    );
  }

  Widget _infoTile(IconData icon, String title, String subtitle) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _primary, size: 18),
      ),
      const SizedBox(width: 14),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: _inkSecondary),
          ),
        ],
      ),
    ],
  );

  final _baseline = FormBaseline();
  bool get _hasChanges => _baseline.changed(
    ready: true,
    values: [
      _currentPasswordController.text,
      _newPasswordController.text,
      _confirmPasswordController.text,
    ],
  );

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      isDirty: () => _hasChanges,
      listenTo: Listenable.merge([
        _currentPasswordController,
        _newPasswordController,
        _confirmPasswordController,
      ]),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _surfaceSubtle,
          body: SafeArea(
            top: false,
            child: Column(
              children: [
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
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'Security Settings',
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
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedBuilder(
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
                            // Info banner
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _primary.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _primary.withOpacity(0.15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _primary.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.security_outlined,
                                      color: _primary,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Keep your account secure by using a strong, unique password.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            _sectionTitle('TWO-FACTOR AUTHENTICATION'),
                            _card(child: const TwoFactorSettingsCard()),
                            const SizedBox(height: 22),
                            _sectionTitle('BIOMETRICS'),
                            _card(child: const BiometricSettingsCard()),
                            const SizedBox(height: 22),
                            _sectionTitle('CHANGE PASSWORD'),
                            _card(
                              child: Column(
                                children: [
                                  _passwordField(
                                    controller: _currentPasswordController,
                                    hint: 'Current Password',
                                    obscureText: _obscureCurrentPassword,
                                    errorText: _currentPasswordError,
                                    onChanged: () {
                                      if (_currentPasswordError != null) {
                                        setState(
                                          () => _currentPasswordError = null,
                                        );
                                      }
                                    },
                                    onToggleVisibility:
                                        () => setState(
                                          () =>
                                              _obscureCurrentPassword =
                                                  !_obscureCurrentPassword,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  _passwordField(
                                    controller: _newPasswordController,
                                    hint: 'New Password',
                                    obscureText: _obscureNewPassword,
                                    onToggleVisibility:
                                        () => setState(
                                          () =>
                                              _obscureNewPassword =
                                                  !_obscureNewPassword,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  _passwordField(
                                    controller: _confirmPasswordController,
                                    hint: 'Confirm New Password',
                                    obscureText: _obscureConfirmPassword,
                                    extraValidator:
                                        (v) =>
                                            v != _newPasswordController.text
                                                ? 'New passwords do not match'
                                                : null,
                                    onToggleVisibility:
                                        () => setState(
                                          () =>
                                              _obscureConfirmPassword =
                                                  !_obscureConfirmPassword,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            _sectionTitle('PASSWORD REQUIREMENTS'),
                            _card(
                              child: Column(
                                children: [
                                  _infoTile(
                                    Icons.check_circle_outline,
                                    'Minimum length',
                                    'At least 6 characters',
                                  ),
                                  const SizedBox(height: 14),
                                  Divider(color: _border, height: 1),
                                  const SizedBox(height: 14),
                                  _infoTile(
                                    Icons.lock_outline,
                                    'Keep it private',
                                    'Never share your password',
                                  ),
                                  const SizedBox(height: 14),
                                  Divider(color: _border, height: 1),
                                  const SizedBox(height: 14),
                                  _infoTile(
                                    Icons.refresh_outlined,
                                    'Update regularly',
                                    'Change your password periodically',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed:
                                    _isSaving ? null : _saveSecuritySettings,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brand,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: const StadiumBorder(),
                                  disabledBackgroundColor: AppColors.brand
                                      .withOpacity(0.5),
                                ),
                                child:
                                    _isSaving
                                        ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                        : const Text(
                                          'Update Password',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                              ),
                            ),
                          ],
                        ),
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
