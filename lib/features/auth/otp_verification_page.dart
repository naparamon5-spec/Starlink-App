import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/features/end_user/home/home_screen.dart';

// Brand tokens — matching login_screen.dart
const _primary = Color(0xFFEB1E23);
const _primaryDark = Color(0xFF760F12);
const _ink = Color(0xFF000000);
const _inkSecondary = Color(0xFF6F6F6F);
const _inkTertiary = Color(0xFFA8A8A8);
const _surface = Color(0xFFFFFFFF);
const _surfaceSubtle = Color(0xFFF4F4F4);
const _border = Color(0xFFE0E0E0);
const _success = Color(0xFF16A34A);
const _successDark = Color(0xFF14532D);

class OtpVerificationPage extends StatefulWidget {
  final String email;

  const OtpVerificationPage({super.key, required this.email});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;

  // Banner state: null = hidden, true = success (green), false = error (red)
  String? _bannerMessage;
  bool _bannerIsSuccess = false;

  bool _canResend = false;
  int _resendSeconds = 30;
  Timer? _timer;

  AnimationController? _bannerAnimController;
  Animation<double>? _bannerFadeAnim;
  Animation<Offset>? _bannerSlideAnim;

  String get _otp => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _bannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bannerFadeAnim = CurvedAnimation(
      parent: _bannerAnimController!,
      curve: Curves.easeOut,
    );
    _bannerSlideAnim = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _bannerAnimController!, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bannerTimer?.cancel();
    _bannerAnimController?.dispose();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    // Cancel any existing timer first
    _timer?.cancel();
    _timer = null;

    setState(() {
      _canResend = false;
      _resendSeconds = 30;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        setState(() {
          _resendSeconds = 0;
          _canResend = true;
        });
        timer.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Timer? _bannerTimer;

  void _showBanner(String message, {required bool isSuccess}) {
    if (!mounted) return;
    _bannerTimer?.cancel();
    setState(() {
      _bannerMessage = message;
      _bannerIsSuccess = isSuccess;
    });
    _bannerAnimController?.forward(from: 0);
    _bannerTimer = Timer(const Duration(seconds: 5), _clearBanner);
  }

  void _clearBanner() {
    if (!mounted) return;
    _bannerAnimController?.reverse().then((_) {
      if (mounted) setState(() => _bannerMessage = null);
    });
  }

  Future<void> _resendCode() async {
    if (_isResending || !_canResend) return;

    // FIX: Start the timer immediately when the button is tapped,
    // before the API call completes, so the UI locks right away.
    _startResendTimer();
    setState(() => _isResending = true);

    try {
      final response = await ApiService.resendOtp({'email': widget.email});
      if (!mounted) return;

      // API returns: { "StatusCode": 200, "message": "...", "data": {...} }
      final dynamic rawCode = response['StatusCode'];
      final int? statusCode =
          rawCode is int ? rawCode : int.tryParse(rawCode?.toString() ?? '');
      final String message =
          (response['message'] as String?) ??
          'OTP sent successfully to your email';

      if (statusCode == 200) {
        // Timer already started above — just show the green banner.
        _showBanner(message, isSuccess: true);
      } else {
        // Something went wrong — show red banner.
        // Do NOT restart the timer; it is already running from the tap above.
        _showBanner(message, isSuccess: false);
      }
    } catch (e) {
      if (!mounted) return;
      _showBanner('Error resending OTP: $e', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 4) {
      _showBanner('Please enter the complete 4-digit code', isSuccess: false);
      return;
    }

    setState(() {
      _isLoading = true;
      _bannerMessage = null;
    });

    try {
      final response = await ApiService.verifyOtp(widget.email, _otp);
      final data = response['data'];
      final accessToken = data?['accessToken'];
      final refreshToken = data?['refreshToken'];

      if (accessToken != null) {
        await ApiService.setAccessToken(accessToken.toString());
        if (refreshToken != null) {
          await ApiService.setRefreshToken(refreshToken.toString());
        }

        final profileResponse = await ApiService.getCurrentUserProfile();

        if (profileResponse['status'] == 'success' &&
            profileResponse['data'] != null) {
          final user = profileResponse['data'];
          final userId = user['id'] ?? user['userId'];
          final userIdStr = userId?.toString() ?? 'undefined';

          final detailedProfileResponse = await ApiService.getUserById(
            userIdStr,
          );

          if (detailedProfileResponse['status'] == 'success' &&
              detailedProfileResponse['data'] != null) {
            final detailedUser = detailedProfileResponse['data'];
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('userProfile', json.encode(detailedUser));
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userType', user['role'] ?? 'end_user');
          await prefs.setString('email', user['email'] ?? '');
          await prefs.setString(
            'name',
            user['name'] ?? user['first_name'] ?? '',
          );
          await prefs.setString('phone', user['phone'] ?? '');
          await prefs.setString('address', user['address'] ?? '');

          if (!mounted) return;

          if (userId != null) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder:
                    (_) => HomeScreen(
                      userId:
                          userId is int
                              ? userId
                              : int.tryParse(userId.toString()) ?? 0,
                      loginMessage: 'Login successful',
                    ),
              ),
              (route) => false,
            );
          } else {
            _showBanner('Failed to get user ID', isSuccess: false);
          }
        } else {
          final user = data?['user'];
          if (user != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('userType', user['role'] ?? 'end_user');
            await prefs.setString('email', user['email'] ?? '');
            await prefs.setString('name', user['name'] ?? '');
            await prefs.setString('phone', user['phone'] ?? '');
            await prefs.setString('address', user['address'] ?? '');

            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder:
                    (_) => HomeScreen(
                      userId: user['id'] ?? 0,
                      loginMessage: 'Login successful',
                    ),
              ),
              (route) => false,
            );
          } else {
            _showBanner('Failed to load user profile', isSuccess: false);
          }
        }
      } else {
        _showBanner('Invalid OTP. Please try again.', isSuccess: false);
      }
    } catch (e) {
      _showBanner('Verification failed: ${e.toString()}', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 64,
      height: 64,
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        maxLength: 1,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: _ink,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: _surfaceSubtle,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 3) {
            _focusNodes[index + 1].requestFocus();
          }
          if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          if (_otp.length == 4) _verifyOtp();
        },
      ),
    );
  }

  Widget _buildBanner() {
    final isSuccess = _bannerIsSuccess;
    final bgColor =
        isSuccess ? _success.withOpacity(0.07) : _primary.withOpacity(0.05);
    final borderColor =
        isSuccess ? _success.withOpacity(0.30) : _primary.withOpacity(0.25);
    final iconColor = isSuccess ? _success : _primary;
    final iconBgColor =
        isSuccess ? _success.withOpacity(0.12) : _primary.withOpacity(0.10);
    final textColor = isSuccess ? _successDark : _primaryDark;
    final icon =
        isSuccess
            ? Icons.check_circle_outline_rounded
            : Icons.error_outline_rounded;

    final banner = Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _bannerMessage!,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          GestureDetector(
            onTap: _clearBanner,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.close_rounded,
                color: iconColor.withOpacity(0.6),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );

    if (_bannerFadeAnim != null && _bannerSlideAnim != null) {
      return SlideTransition(
        position: _bannerSlideAnim!,
        child: FadeTransition(opacity: _bannerFadeAnim!, child: banner),
      );
    }
    return banner;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topPad = MediaQuery.of(context).padding.top;

    final emailParts = widget.email.split('@');
    final maskedEmail =
        emailParts.length == 2
            ? '${emailParts[0].substring(0, emailParts[0].length.clamp(0, 2))}***@${emailParts[1]}'
            : widget.email;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: _surface,
        body: Stack(
          children: [
            // ── Fixed gradient header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _OtpHeader(height: size.height * 0.30, topPad: topPad),
            ),

            // ── Scrollable content
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(top: size.height * 0.30),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Container(
                  color: _surface,
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter verification code',
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
                            const TextSpan(text: 'We sent a 4-digit code to '),
                            TextSpan(
                              text: maskedEmail,
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(
                              text: '. Enter it below to continue.',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),

                      // OTP boxes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(4, _buildOtpBox),
                      ),

                      // Banner (success green / error red)
                      if (_bannerMessage != null) _buildBanner(),

                      const SizedBox(height: 32),

                      // Verify button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            disabledBackgroundColor: _primary.withOpacity(0.5),
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
                                      valueColor: AlwaysStoppedAnimation<Color>(
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

                      const SizedBox(height: 20),

                      // Resend row — timer OR resend button
                      Center(
                        child:
                            _canResend
                                ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      "Didn't receive it? ",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _inkSecondary,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: _isResending ? null : _resendCode,
                                      child:
                                          _isResending
                                              ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(_primary),
                                                ),
                                              )
                                              : const Text(
                                                'Resend code',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: _primary,
                                                  decoration:
                                                      TextDecoration.underline,
                                                  decorationColor: _primary,
                                                ),
                                              ),
                                    ),
                                  ],
                                )
                                : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.schedule_rounded,
                                      size: 14,
                                      color: _inkTertiary,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Resend in $_resendSeconds seconds',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: _inkTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Back button overlay on header
            Positioned(
              top: topPad + 8,
              left: 8,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header widget ─────────────────────────────────────────────────────────────

class _OtpHeader extends StatelessWidget {
  final double height;
  final double topPad;
  const _OtpHeader({required this.height, required this.topPad});

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
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: topPad),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Check your inbox',
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
