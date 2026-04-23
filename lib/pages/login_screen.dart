import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'customer/home/customer_home_screen.dart';
import 'admin/admin_home_screen.dart';
import 'end-user/home/home_screen.dart';
import 'forgot_password.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'otp_verification_page.dart';

// Brand tokens (matching admin_home_screen.dart)
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isPasswordVisible = false;
  bool _isAgreedToTerms = false;
  bool _showValidation = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _emailError;
  String? _passwordError;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  AnimationController? _errorAnimController;
  Animation<double>? _errorFadeAnim;
  Animation<Offset>? _errorSlideAnim;

  @override
  void initState() {
    super.initState();
    _errorAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _errorFadeAnim = CurvedAnimation(
      parent: _errorAnimController!,
      curve: Curves.easeOut,
    );
    _errorSlideAnim = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _errorAnimController!, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _errorAnimController?.dispose();
    super.dispose();
  }

  bool _isEmailValid(String email) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
    _errorAnimController?.forward(from: 0);
  }

  void _clearError() {
    if (!mounted) return;
    setState(() => _errorMessage = null);
    _errorAnimController?.reverse();
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

  Future<void> _handleLogin() async {
    setState(() {
      _showValidation = true;
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate() || !_isAgreedToTerms) return;
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.login(
        _emailController.text,
        _passwordController.text,
      );

      if (response.containsKey('userId') && response['flag'] == false) {
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationPage(email: _emailController.text),
          ),
        );
      } else if (response.containsKey('accessToken')) {
        final accessToken = response['accessToken'];
        final refreshToken = response['refreshToken'];

        if (accessToken != null)
          await ApiService.setAccessToken(accessToken.toString());
        if (refreshToken != null)
          await ApiService.setRefreshToken(refreshToken.toString());

        final profileResponse = await ApiService.getCurrentUserProfile();

        if (profileResponse['status'] == 'success' &&
            profileResponse['data'] != null) {
          final userData = profileResponse['data'];
          final userIdStr = userData['id']?.toString() ?? 'undefined';
          final detailed = await ApiService.getUserById(userIdStr);

          if (detailed['status'] == 'success' && detailed['data'] != null) {
            final prefs = await SharedPreferences.getInstance();
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

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => _getScreenForRole(userRole, userId: userId),
            ),
          );
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
        _setError('Invalid email or password.');
      }
    } catch (_) {
      _setError('Invalid email or password.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;

    // ── Reduced from 0.38 → 0.26 so the header is shorter
    //    and the form card sits higher on screen.
    const headerFraction = 0.30;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: _surface,
        body: Stack(
          children: [
            // ── Fixed gradient header ──────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopHeader(
                height: size.height * headerFraction,
                topPad: topPad,
              ),
            ),

            // ── Scrollable form ────────────────────────────────────────────
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(top: size.height * headerFraction),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Container(
                  color: _surface,
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                  child: Form(
                    key: _formKey,
                    autovalidateMode:
                        _showValidation
                            ? AutovalidateMode.always
                            : AutovalidateMode.disabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        const Text(
                          'Sign in to your account',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Enter your credentials to continue.',
                          style: TextStyle(fontSize: 13, color: _inkSecondary),
                        ),

                        const SizedBox(height: 24),

                        // Email
                        _fieldLabel('Email Address'),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(fontSize: 14, color: _ink),
                          decoration: _inputDecoration(
                            hint: 'you@example.com',
                            prefixIcon: Icons.mail_outline_rounded,
                            errorText: _emailError,
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return 'Please enter your email address';
                            if (!_isEmailValid(v))
                              return 'Please enter a valid email address';
                            return null;
                          },
                        ),

                        const SizedBox(height: 18),

                        // Password
                        _fieldLabel('Password'),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: !_isPasswordVisible,
                          style: const TextStyle(fontSize: 14, color: _ink),
                          decoration: _inputDecoration(
                            hint: 'Enter your password',
                            prefixIcon: Icons.lock_outline_rounded,
                            errorText: _passwordError,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: _inkTertiary,
                                size: 20,
                              ),
                              onPressed:
                                  () => setState(
                                    () =>
                                        _isPasswordVisible =
                                            !_isPasswordVisible,
                                  ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty)
                              return 'Please enter your password';
                            if (v.length < 6)
                              return 'Password must be at least 6 characters';
                            return null;
                          },
                        ),

                        // Error banner
                        if (_errorMessage != null)
                          _errorFadeAnim != null && _errorSlideAnim != null
                              ? SlideTransition(
                                position: _errorSlideAnim!,
                                child: FadeTransition(
                                  opacity: _errorFadeAnim!,
                                  child: _buildErrorBanner(),
                                ),
                              )
                              : _buildErrorBanner(),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordPage(),
                                  ),
                                ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 8,
                              ),
                              overlayColor: Colors.transparent,
                            ),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _primary,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Terms checkbox
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: _isAgreedToTerms,
                                  onChanged:
                                      (v) => setState(
                                        () => _isAgreedToTerms = v ?? false,
                                      ),
                                  activeColor: _primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  side: const BorderSide(
                                    color: _inkTertiary,
                                    width: 1.5,
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 9),
                              RichText(
                                text: const TextSpan(
                                  text: 'I agree to the ',
                                  style: TextStyle(
                                    color: _inkSecondary,
                                    fontSize: 13,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'User Agreement',
                                      style: TextStyle(
                                        color: _primary,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                        decorationColor: _primary,
                                      ),
                                    ),
                                    TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: TextStyle(
                                        color: _primary,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                        decorationColor: _primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_showValidation && !_isAgreedToTerms)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.info_outline,
                                    color: _primary,
                                    size: 12,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'You must agree to continue',
                                    style: TextStyle(
                                      color: _primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 28),

                        // Sign In button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              disabledBackgroundColor: _primary.withOpacity(
                                0.5,
                              ),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
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
    );
  }

  Widget _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: _ink,
      letterSpacing: 0.1,
    ),
  );

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withOpacity(0.25), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: _primary,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: _primaryDark,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          GestureDetector(
            onTap: _clearError,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.close_rounded,
                color: _primary.withOpacity(0.6),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    String? errorText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _inkTertiary, fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: _inkTertiary, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _surfaceSubtle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      errorStyle: const TextStyle(color: _primary, fontSize: 12),
      errorMaxLines: 2,
      errorText: errorText,
    );
  }
}

// ── Top gradient header ───────────────────────────────────────────────────────

class _TopHeader extends StatelessWidget {
  final double height;
  final double topPad;
  const _TopHeader({required this.height, required this.topPad});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEB1E23), Color(0xFF760F12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: -30,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // Logo + tagline — tighter vertical padding
          Padding(
            padding: EdgeInsets.only(top: topPad),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SvgPicture.asset(
                      'assets/images/logo_full.svg',
                      height: 40, // reduced from 52
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10), // reduced from 18
                  Text(
                    'Welcome Back!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
