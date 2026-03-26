import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import 'reset_password.dart';

// ── Brand tokens ──────────────────────────────────────────────────────────────
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);
const _success = Color(0xFF24A148);

class VerificationCodeScreen extends StatefulWidget {
  final String email;

  const VerificationCodeScreen({super.key, required this.email});

  @override
  State<VerificationCodeScreen> createState() => _VerificationCodeScreenState();
}

class _VerificationCodeScreenState extends State<VerificationCodeScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;
  int _resendAttempts = 0;
  bool _canResend = true;
  int _resendCooldown = 60;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _codeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    _errorAnimController?.dispose();
    super.dispose();
  }

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

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/routes/verify_code.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.email,
          'code': _codeController.text.trim(),
        }),
      );

      if (!mounted) return;

      final data = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        if (data['status'] == 'success' || data['success'] == true) {
          String? token;

          if (data.containsKey('data') &&
              data['data'] is Map<String, dynamic>) {
            final dataObj = data['data'] as Map<String, dynamic>;
            token =
                dataObj['resetToken']?.toString() ??
                dataObj['reset_token']?.toString() ??
                dataObj['token']?.toString();
          }

          token ??=
              data['token']?.toString() ??
              data['reset_token']?.toString() ??
              data['resetToken']?.toString();

          if (token != null) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder:
                    (context) => ResetPasswordScreen(
                      token: token!,
                      email: widget.email,
                      verificationCode: _codeController.text.trim(),
                    ),
              ),
            );
          } else {
            _setError(
              'Unable to proceed with password reset. Please try again.',
            );
          }
        } else {
          final error = data['message'] as String? ?? data['error'] as String?;
          if (error?.toLowerCase().contains('expired') ?? false) {
            _setError(
              'Verification code has expired. Please request a new one.',
            );
            _codeController.clear();
            setState(() {
              _canResend = true;
              _resendCooldown = 0;
            });
          } else {
            _setError(error ?? 'Invalid verification code');
          }
        }
      } else {
        _setError('Failed to verify code. Please try again.');
      }
    } catch (e) {
      _setError('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/resend_code.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': widget.email}),
      );

      if (!mounted) return;

      Map<String, dynamic> data;
      try {
        data = json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        _setError(
          'Server error: Unable to send verification code. Please contact support.',
        );
        return;
      }

      if (response.statusCode == 200 &&
          (data['status'] == 'success' || data['success'] == true)) {
        setState(() {
          _resendAttempts++;
          _canResend = false;
          _resendCooldown = 60;
          _codeController.clear();
        });
        _startCooldownTimer();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                (data['message'] as String?) ??
                    'Verification code resent successfully',
              ),
              backgroundColor: _success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        final error = data['message'] as String? ?? data['error'] as String?;
        _setError(error ?? 'Failed to resend verification code');
      }
    } catch (e) {
      _setError('An error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startCooldownTimer() {
    if (_resendCooldown > 0) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() => _resendCooldown--);
          _startCooldownTimer();
        }
      });
    } else {
      if (mounted) {
        setState(() {
          _canResend = true;
          _resendCooldown = 60;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: _surface,
        body: Stack(
          children: [
            // ── Compact gradient header ────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopHeader(height: size.height * 0.30, topPad: topPad),
            ),

            // ── Scrollable form ────────────────────────────────────────────
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(top: size.height * 0.30),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Container(
                  color: _surface,
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Heading ──────────────────────────────────────
                        const Text(
                          'Enter Verification Code',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 13,
                              color: _inkSecondary,
                              height: 1.5,
                            ),
                            children: [
                              const TextSpan(
                                text: 'We sent a 6-digit code to ',
                              ),
                              TextSpan(
                                text: widget.email,
                                style: const TextStyle(
                                  color: _primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const TextSpan(
                                text: '. Enter it below to continue.',
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Code input ───────────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: _surfaceSubtle,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _border),
                          ),
                          child: TextFormField(
                            controller: _codeController,
                            focusNode: _codeFocusNode,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 6,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 12,
                              color: _ink,
                            ),
                            decoration: const InputDecoration(
                              counterText: '',
                              hintText: '••••••',
                              hintStyle: TextStyle(
                                fontSize: 28,
                                letterSpacing: 12,
                                color: _inkTertiary,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 16,
                              ),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) {
                              if (value.length == 6) _verifyCode();
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty)
                                return 'Please enter the verification code';
                              if (value.length != 6)
                                return 'Code must be 6 digits';
                              if (!RegExp(r'^\d{6}$').hasMatch(value))
                                return 'Code must contain only numbers';
                              return null;
                            },
                          ),
                        ),

                        // ── Error banner ─────────────────────────────────
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

                        const SizedBox(height: 28),

                        // ── Verify button ─────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verifyCode,
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
                                      'Verify Code',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Resend ────────────────────────────────────────
                        Center(
                          child: TextButton(
                            onPressed:
                                _canResend && !_isLoading ? _resendCode : null,
                            style: TextButton.styleFrom(
                              overlayColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                            ),
                            child: Text(
                              _canResend
                                  ? 'Didn\'t receive a code? Resend'
                                  : 'Resend in $_resendCooldown seconds',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _canResend ? _primary : _inkTertiary,
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

            // ── Back button overlaid on header ─────────────────────────────
            Positioned(
              top: topPad + 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
}

// ── Compact gradient header ───────────────────────────────────────────────────

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
          // Icon + label
          Padding(
            padding: EdgeInsets.only(top: topPad),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Check Your Email',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
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
