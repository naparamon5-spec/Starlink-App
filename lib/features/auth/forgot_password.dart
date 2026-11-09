import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:starlink_app/features/auth/widgets/auth_shell.dart';
import 'package:starlink_app/services/api_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await ApiService.forgotPassword(email);
      if (!mounted) return;

      if (data['status'] == 'success' || data['success'] == true) {
        AppToast.success(context, 'Reset link sent. Check your email.');
        Navigator.of(context).pop();
      } else {
        var error = data['message'] as String? ?? 'Failed to send reset link';
        final errorLower = error.toLowerCase();
        if (errorLower.contains('not found') ||
            errorLower.contains('not registered') ||
            errorLower.contains('does not exist')) {
          error = 'This email is not registered in our system.';
        }
        AppToast.error(context, error);
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Network error. Please check your connection.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AuthHeading(
              title: 'Reset your password',
              subtitle: "Enter your email and we'll send you a reset link.",
            ),
            const SizedBox(height: 26),
            const AuthFieldLabel('Email'),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading,
              style: const TextStyle(fontSize: 15, color: AppColors.ink),
              decoration: authInputDecoration(
                hint: 'you@company.com.ph',
                prefixIcon: Icons.mail_outline_rounded,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                ).hasMatch(v)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            AuthSubmitButton(
              label: 'Send reset link',
              loading: _isLoading,
              onPressed: _handleForgotPassword,
            ),
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: AppColors.brand),
                child: const Text(
                  '← Back to sign in',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
