import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../login_screen.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _success = Color(0xFF24A148);
const _ink = Color(0xFF1A1A1A);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF7F7F7);
const _border = Color(0xFFEAEAEA);

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  String? _focusedField;

  // Password strength
  double _passwordStrength = 0;
  String _passwordStrengthLabel = '';
  Color _passwordStrengthColor = Colors.transparent;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _fadeController.forward(),
    );
    _newPasswordController.addListener(_evaluatePasswordStrength);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _evaluatePasswordStrength() {
    final val = _newPasswordController.text;
    double strength = 0;
    if (val.length >= 8) strength += 0.25;
    if (val.contains(RegExp(r'[A-Z]'))) strength += 0.25;
    if (val.contains(RegExp(r'[0-9]'))) strength += 0.25;
    if (val.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) strength += 0.25;

    String label;
    Color color;
    if (strength <= 0.25) {
      label = 'Weak';
      color = Colors.red;
    } else if (strength <= 0.5) {
      label = 'Fair';
      color = Colors.orange;
    } else if (strength <= 0.75) {
      label = 'Good';
      color = Colors.amber.shade700;
    } else {
      label = 'Strong';
      color = _success;
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthLabel = val.isEmpty ? '' : label;
      _passwordStrengthColor = val.isEmpty ? Colors.transparent : color;
    });
  }

  Future<int?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  Future<void> _saveSecuritySettings() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnack('New passwords do not match', isError: true);
      return;
    }

    final userId = await _getUserId();
    if (userId == null) {
      _showSnack('User not found. Please log in again.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final response = await http.post(
        Uri.parse(
          'http://10.0.2.2/starlink_app/backend/routes/change_password.php',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'current_password': _currentPasswordController.text,
          'new_password': _newPasswordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['success']) {
        if (mounted) _showSuccessDialog();
      } else {
        _showSnack(
          data['message'] ?? 'Failed to update password.',
          isError: true,
        );
      }
    } catch (e) {
      _showSnack('An error occurred. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 36, 28, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success icon with gradient bg
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF24A148), Color(0xFF1A7A35)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _success.withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_open_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Password Updated!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your password was changed successfully. Please log in again for security.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: _inkSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (_) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Continue to Login',
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
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String fieldKey,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    Widget? extra,
  }) {
    final isActive = _focusedField == fieldKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 2),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _inkSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Focus(
          onFocusChange:
              (f) => setState(() => _focusedField = f ? fieldKey : null),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isActive ? _primary : _border,
                width: isActive ? 1.5 : 1,
              ),
              boxShadow:
                  isActive
                      ? [
                        BoxShadow(
                          color: _primary.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                      : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
            ),
            child: TextFormField(
              controller: controller,
              obscureText: obscure,
              style: const TextStyle(
                color: _ink,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: isActive ? _primary : _inkTertiary,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: _inkTertiary,
                  ),
                  onPressed: onToggle,
                  splashRadius: 20,
                ),
                border: InputBorder.none,
                hintText: 'Enter $label',
                hintStyle: const TextStyle(
                  color: _inkTertiary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                errorStyle: const TextStyle(height: 0),
              ),
              validator: validator,
            ),
          ),
        ),
        if (extra != null) ...[const SizedBox(height: 8), extra],
      ],
    );
  }

  Widget _buildStrengthIndicator() {
    if (_newPasswordController.text.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _passwordStrength,
            backgroundColor: _border,
            valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              'Strength: ',
              style: const TextStyle(fontSize: 11, color: _inkTertiary),
            ),
            Text(
              _passwordStrengthLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _passwordStrengthColor,
              ),
            ),
            const Spacer(),
            Text(
              'Use 8+ chars, uppercase, numbers & symbols',
              style: const TextStyle(fontSize: 10, color: _inkTertiary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _ink,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _surfaceSubtle,
        body: Column(
          children: [
            // ── AppBar ──────────────────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEB1E23), Color(0xFF9B1215)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Security Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Body ────────────────────────────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Hero banner ─────────────────────────────────────
                      Container(
                        width: double.infinity,
                        color: _surface,
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFEB1E23),
                                    Color(0xFF760F12),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primary.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.lock_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Change Password',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: _ink,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Keep your account safe with a strong password',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _inkTertiary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(height: 1, color: _border),

                      // ── Form ─────────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Current password section
                              _buildSectionCard(
                                title: 'Verify Identity',
                                child: _buildPasswordField(
                                  controller: _currentPasswordController,
                                  label: 'Current Password',
                                  fieldKey: 'current',
                                  obscure: _obscureCurrent,
                                  onToggle:
                                      () => setState(
                                        () =>
                                            _obscureCurrent = !_obscureCurrent,
                                      ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Required';
                                    }
                                    return null;
                                  },
                                ),
                              ),

                              const SizedBox(height: 20),

                              // New password section
                              _buildSectionCard(
                                title: 'New Password',
                                child: Column(
                                  children: [
                                    _buildPasswordField(
                                      controller: _newPasswordController,
                                      label: 'New Password',
                                      fieldKey: 'new',
                                      obscure: _obscureNew,
                                      onToggle:
                                          () => setState(
                                            () => _obscureNew = !_obscureNew,
                                          ),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return 'Required';
                                        }
                                        if (v.length < 6) {
                                          return 'At least 6 characters';
                                        }
                                        return null;
                                      },
                                      extra: _buildStrengthIndicator(),
                                    ),
                                    const SizedBox(height: 14),
                                    _buildPasswordField(
                                      controller: _confirmPasswordController,
                                      label: 'Confirm New Password',
                                      fieldKey: 'confirm',
                                      obscure: _obscureConfirm,
                                      onToggle:
                                          () => setState(
                                            () =>
                                                _obscureConfirm =
                                                    !_obscureConfirm,
                                          ),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return 'Required';
                                        }
                                        if (v != _newPasswordController.text) {
                                          return 'Passwords do not match';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Save button
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed:
                                      _isSaving ? null : _saveSecuritySettings,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primary,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: _primary
                                        .withOpacity(0.5),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child:
                                      _isSaving
                                          ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                          : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: const [
                                              Icon(
                                                Icons.lock_reset_rounded,
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Update Password',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                            ],
                                          ),
                                ),
                              ),

                              const SizedBox(height: 12),
                              Center(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: _inkTertiary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
