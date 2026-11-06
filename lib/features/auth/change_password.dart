import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:starlink_app/services/api_service.dart';

const _primary = Color(0xFF133341);
const _success = Color(0xFF10B981);
const _ink = Color(0xFF111111);
const _inkSecondary = Color(0xFF666666);
const _inkTertiary = Color(0xFF888888);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF8F8F8);
const _border = Color(0xFFD7D7D7);

class AdminChangePasswordPage extends StatefulWidget {
  const AdminChangePasswordPage({super.key});

  @override
  State<AdminChangePasswordPage> createState() =>
      _AdminChangePasswordPageState();
}

class _AdminChangePasswordPageState extends State<AdminChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.changePassword(
        oldPassword: _currentCtrl.text.trim(),
        newPassword: _newCtrl.text.trim(),
      );

      if (!mounted) return;

      if (result['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password changed successfully.'),
            backgroundColor: _success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context);
      } else {
        setState(() {
          _errorMessage =
              result['message']?.toString() ?? 'Failed to change password.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        // Same navy app bar as the other pages (from the app theme).
        appBar: AppBar(title: const Text('Change Password')),
        backgroundColor: _surfaceSubtle,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              // ── Content ──────────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info banner
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _primary.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _primary.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: _primary,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Your new password must be at least 8 characters long.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _primary,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Fields card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _PasswordField(
                                controller: _currentCtrl,
                                label: 'Current Password',
                                hint: 'Enter your current password',
                                show: _showCurrent,
                                onToggle:
                                    () => setState(
                                      () => _showCurrent = !_showCurrent,
                                    ),
                                validator:
                                    (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Enter your current password.'
                                            : null,
                              ),
                              const SizedBox(height: 4),
                              Divider(color: _border.withOpacity(0.5)),
                              const SizedBox(height: 4),
                              _PasswordField(
                                controller: _newCtrl,
                                label: 'New Password',
                                hint: 'Enter your new password',
                                show: _showNew,
                                onToggle:
                                    () => setState(() => _showNew = !_showNew),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Enter a new password.';
                                  }
                                  if (v.trim().length < 8) {
                                    return 'Use at least 8 characters.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 4),
                              Divider(color: _border.withOpacity(0.5)),
                              const SizedBox(height: 4),
                              _PasswordField(
                                controller: _confirmCtrl,
                                label: 'Confirm New Password',
                                hint: 'Re-enter your new password',
                                show: _showConfirm,
                                onToggle:
                                    () => setState(
                                      () => _showConfirm = !_showConfirm,
                                    ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Re-enter your new password.';
                                  }
                                  if (v.trim() != _newCtrl.text.trim()) {
                                    return 'Passwords don\'t match.';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                        // Error message
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.brand.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppColors.dangerInk,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.dangerInk,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 28),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.brand
                                  .withOpacity(0.5),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: const StadiumBorder(),
                            ),
                            child:
                                _loading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
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
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Password Field Widget ────────────────────────────────────────────────────

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool show;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.show,
    required this.onToggle,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _inkSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: !show,
          style: const TextStyle(fontSize: 14, color: _ink),
          validator: validator,
          // After the first submit, each error clears as soon as it's fixed.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: _inkTertiary),
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: _primary,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                show
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: _inkTertiary,
              ),
              onPressed: onToggle,
              splashRadius: 18,
            ),
            filled: true,
            fillColor: AppColors.paper,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFE90408),
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFE90408),
                width: 1.5,
              ),
            ),
            // Web portal error text: small, medium weight, dark red.
            errorStyle: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.dangerInk,
              height: 1.3,
            ),
            errorMaxLines: 2,
          ),
        ),
      ],
    );
  }
}
