import 'package:starlink_app/shared/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:starlink_app/features/customer/home/customer_home_screen.dart';
import 'package:starlink_app/features/admin/admin_home_screen.dart';
import 'package:starlink_app/features/end_user/home/home_screen.dart';
import 'package:starlink_app/features/auth/forgot_password.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/services/push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/features/auth/otp_verification_page.dart';
import 'package:starlink_app/features/auth/two_factor/authenticator_widgets.dart';
import 'package:starlink_app/features/auth/widgets/auth_shell.dart';
import 'package:starlink_app/features/auth/widgets/biometric_sign_in_panel.dart';
import 'package:starlink_app/services/biometric_service.dart';

// Legal links shown below the login form.
// TODO(Ardent): confirm these public URLs point to the live pages before release.
const _userAgreementUrl =
    'https://starlink.ardentnetworks.com.ph/terms-of-service';
const _privacyPolicyUrl =
    'https://starlink.ardentnetworks.com.ph/privacy-policy';
const _supportUrl = 'https://starlink.ardentnetworks.com.ph/support';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isPasswordVisible = false;
  bool _rememberEmail = false;
  bool _showValidation = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool _bioChecked = false;
  bool _bioBusy = false;
  bool _showPasswordForm = false;
  String? _bioEmail;
  BiometricMethod _method = BiometricMethod.pin;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      AppToast.error(context, 'Could not open $url');
    }
  }

  @override
  void initState() {
    super.initState();
    _restoreRememberedEmail();
    _loadBiometric();
  }

  Future<void> _loadBiometric() async {
    final email = await BiometricService.savedEmail();
    final method = await BiometricService.bestMethod();
    // No Face ID, fingerprint or PIN left on this phone: password it is.
    final available = await BiometricService.isAvailable();
    if (!mounted) return;
    setState(() {
      _bioEmail = available ? email : null;
      _method = method;
      _bioChecked = true;
    });
  }

  Future<void> _restoreRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(ApiService.rememberedEmailKey);
    if (!mounted || saved == null || saved.isEmpty) return;
    setState(() {
      _emailController.text = saved;
      _rememberEmail = true;
    });
  }

  Future<void> _persistRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberEmail) {
      await prefs.setString(ApiService.rememberedEmailKey, _emailController.text.trim());
    } else {
      await prefs.remove(ApiService.rememberedEmailKey);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isEmailValid(String email) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  Widget _getScreenForRole(String role, {int userId = 0}) {
    switch (role.toLowerCase()) {
      case 'admin' || 'agent':
        return const AdminHomeScreen();
      case 'end_user' || 'end-user' || 'enduser':
        return HomeScreen(userId: userId, loginMessage: 'Login successful');
      case 'customer' || 'biller':
      default:
        return CustomerHomeScreen(loginMessage: 'Login successful');
    }
  }

  /// Loads the signed-in user and opens their home. False if it couldn't.
  Future<bool> _openHomeFromProfile() async {
    final profileResponse = await ApiService.getCurrentUserProfile();
    if (profileResponse['status'] != 'success' ||
        profileResponse['data'] == null) {
      return false;
    }
    final userData = profileResponse['data'];
    final userIdStr = userData['id']?.toString() ?? 'undefined';
    final detailed = await ApiService.getUserById(userIdStr);
    final prefs = await SharedPreferences.getInstance();
    if (detailed['status'] == 'success' && detailed['data'] != null) {
      await prefs.setString('userProfile', json.encode(detailed['data']));
    }

    final userRole =
        (userData['role'] ?? userData['type'] ?? 'customer')
            .toString()
            .toLowerCase();
    final userId =
        (userData['id'] is int)
            ? userData['id'] as int
            : int.tryParse(userData['id']?.toString() ?? '') ?? 0;
    await prefs.setInt('user_id', userId);

    if (!mounted) return true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _getScreenForRole(userRole, userId: userId),
      ),
    );
    return true;
  }

  /// Device check first, then the saved session. Same order as ANI HRIS.
  Future<void> _signInWithBiometrics() async {
    if (_bioBusy) return;
    setState(() => _bioBusy = true);
    final result = await BiometricService.authenticate(
      'Sign in to Starlink',
      biometricOnly: _method.isBiometric,
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() => _bioBusy = false);
      AppToast.error(
        context,
        result.message ?? 'Authentication was not recognized. Please try again.',
      );
      return;
    }

    final restored = await ApiService.restoreBiometricSession();
    if (!mounted) return;
    if (restored['status'] != 'success') {
      final expired = restored['expired'] == true;
      setState(() {
        _bioBusy = false;
        if (expired) {
          _emailController.text = _bioEmail ?? _emailController.text;
          _bioEmail = null;
        }
      });
      AppToast.error(
        context,
        expired
            ? 'Your biometric sign-in has expired. Please sign in with your password.'
            : 'Cannot reach the server. Check your connection and try again.',
      );
      return;
    }

    PushService.instance.registerWithBackend();
    final opened = await _openHomeFromProfile();
    if (!mounted) return;
    setState(() => _bioBusy = false);
    if (!opened) {
      AppToast.error(context, 'Failed to load user profile. Please try again.');
    }
  }

  Future<void> _handleLogin() async {
    setState(() {
      _showValidation = true;
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.login(
        _emailController.text,
        _passwordController.text,
      );

      if (response.containsKey('userId') && response['flag'] == false) {
        await _persistRememberedEmail();
        // Two-factor step (authenticator app). `setupRequired` means the
        // account has no authenticator linked yet, so show the QR first.
        final setup =
            response['setupRequired'] == true
                ? AuthenticatorSetupInfo.fromMap(response)
                : null;
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => OtpVerificationPage(
                  email: _emailController.text.trim(),
                  setup: setup,
                ),
          ),
        );
      } else if (response.containsKey('accessToken')) {
        await _persistRememberedEmail();
        await BiometricService.handleSignIn(_emailController.text);
        final accessToken = response['accessToken'];
        final refreshToken = response['refreshToken'];

        if (accessToken != null) {
          await ApiService.setAccessToken(accessToken.toString());
        }
        if (refreshToken != null) {
          await ApiService.setRefreshToken(refreshToken.toString());
        }
        // Register this device for push notifications (best-effort).
        PushService.instance.registerWithBackend();

        if (await _openHomeFromProfile()) {
          // Navigated.
        } else if (response.containsKey('user')) {
          final userData = response['user'];
          final userRole =
              (userData['role'] ?? userData['type'] ?? 'customer')
                  .toString()
                  .toLowerCase();
          final userId =
              (userData['id'] is int)
                  ? userData['id'] as int
                  : int.tryParse(userData['id']?.toString() ?? '') ?? 0;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('user_id', userId);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => _getScreenForRole(userRole, userId: userId),
            ),
          );
        } else {
          _setError('Failed to load user profile. Please try again.');
        }
      } else {
        final msg = response['message']?.toString() ?? '';
        final unreachable =
            msg.contains('Cannot reach the server') ||
        msg.contains('SocketException') ||
            msg.contains('Failed host lookup') ||
            msg.contains('TimeoutException') ||
            msg.contains('HandshakeException');
        _setError(
          unreachable
              ? 'Cannot reach the server. Check your connection and try again.'
              : 'Invalid email or password.',
        );
      }
    } catch (_) {
      _setError('Invalid email or password.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_bioChecked) return const AuthShell(child: SizedBox(height: 320));
    final bioEmail = _bioEmail;
    if (bioEmail != null && !_showPasswordForm) {
      return AuthShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AuthHeading(
              title: 'Sign in',
              subtitle: 'Welcome back to the Ardent Starlink Portal.',
            ),
            const SizedBox(height: 26),
            BiometricSignInPanel(
              email: bioEmail,
              method: _method,
              busy: _bioBusy,
              onSignIn: _signInWithBiometrics,
              onUsePassword:
                  () => setState(() {
                    _emailController.text = bioEmail;
                    _showPasswordForm = true;
                  }),
            ),
            const SizedBox(height: 10),
            _legalLinks(),
          ],
        ),
      );
    }
    return AuthShell(
      child: Form(
        key: _formKey,
        autovalidateMode:
            _showValidation
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AuthHeading(
              title: 'Sign in',
              subtitle: 'Welcome back to the Ardent Starlink Portal.',
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
                  return 'Please enter your email address';
                }
                if (!_isEmailValid(v)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const AuthFieldLabel('Password'),
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              enabled: !_isLoading,
              style: const TextStyle(fontSize: 15, color: AppColors.ink),
              decoration: authInputDecoration(
                hint: '••••••••',
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  tooltip:
                      _isPasswordVisible ? 'Hide password' : 'Show password',
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.inkFaint,
                    size: 20,
                  ),
                  onPressed:
                      () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible,
                      ),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please enter your password';
                }
                if (v.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap:
                        () => setState(() => _rememberEmail = !_rememberEmail),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _rememberEmail,
                            onChanged:
                                (v) =>
                                    setState(() => _rememberEmail = v ?? false),
                            activeColor: AppColors.brand,
                            side: const BorderSide(
                              color: AppColors.lineStrong,
                              width: 1.5,
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'Remember me',
                            style: TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordPage(),
                        ),
                      ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.dangerInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            AuthSubmitButton(
              label: 'Sign in',
              loading: _isLoading,
              onPressed: _handleLogin,
            ),
            if (bioEmail != null)
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _showPasswordForm = false),
                  style: TextButton.styleFrom(foregroundColor: AppColors.brand),
                  icon: const Icon(Icons.fingerprint_rounded, size: 16),
                  label: const Text(
                    'Use biometrics instead',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            const SizedBox(height: 22),
            _legalLinks(),
          ],
        ),
      ),
    );
  }

  Widget _legalLinks() => Center(
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      children: [
        _legalLink('Terms of Service', _userAgreementUrl),
        _legalLink('Privacy Policy', _privacyPolicyUrl),
        _legalLink('Contact Support', _supportUrl),
      ],
    ),
  );

  Widget _legalLink(String label, String url) => InkWell(
    onTap: () => _openUrl(url),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.inkMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
