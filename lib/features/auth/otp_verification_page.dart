import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:starlink_app/core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starlink_app/features/admin/admin_home_screen.dart';
import 'package:starlink_app/features/auth/two_factor/authenticator_widgets.dart';
import 'package:starlink_app/services/biometric_service.dart';
import 'package:starlink_app/features/customer/home/customer_home_screen.dart';
import 'package:starlink_app/services/api_service.dart';
import 'package:starlink_app/services/push_service.dart';
import 'package:starlink_app/features/end_user/home/home_screen.dart';

// Brand tokens — matching login_screen.dart
const _primary = Color(0xFF133341);
const _primaryDark = Color(0xFF0C2029);
const _ink = Color(0xFF111111);
const _inkSecondary = Color(0xFF666666);
const _surface = Color(0xFFFFFFFF);
const _success = Color(0xFF10B981);
const _successDark = Color(0xFF14532D);

/// Second sign-in step: two-factor authentication with an authenticator app
/// (Google Authenticator / Microsoft Authenticator), same as eForward and
/// ANI HRIS. Replaces the old emailed 4-digit OTP.
///
/// When [setup] is given the account has no authenticator linked yet, so the
/// page first shows the QR code / setup key; the first correct code links it
/// and signs the user in.
class OtpVerificationPage extends StatefulWidget {
  final String email;
  final AuthenticatorSetupInfo? setup;

  const OtpVerificationPage({super.key, required this.email, this.setup});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();

  bool _isLoading = false;

  // Banner state: null = hidden, true = success (green), false = error (red)
  String? _bannerMessage;
  bool _bannerIsSuccess = false;

  AnimationController? _bannerAnimController;
  Animation<double>? _bannerFadeAnim;
  Animation<Offset>? _bannerSlideAnim;

  bool get _isSetup => widget.setup != null;
  String get _otp => _codeController.text.trim();

  @override
  void initState() {
    super.initState();
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
    _bannerTimer?.cancel();
    _bannerAnimController?.dispose();
    _codeController.dispose();
    super.dispose();
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

  Widget _homeForRole(String role, int userId) {
    switch (role.toLowerCase()) {
      case 'admin' || 'agent':
        return const AdminHomeScreen();
      case 'end_user' || 'end-user' || 'enduser':
        return HomeScreen(userId: userId, loginMessage: 'Login successful');
      default:
        return CustomerHomeScreen(loginMessage: 'Login successful');
    }
  }

  Future<void> _verifyOtp() async {
    if (_isLoading) return;
    if (_otp.length != kTotpLength) {
      _showBanner(
        'Enter the 6-digit code from your authenticator app',
        isSuccess: false,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _bannerMessage = null;
    });

    try {
      final response = await ApiService.verifyOtp(widget.email, _otp);
      if (response['ok'] != true) {
        _codeController.clear();
        _showBanner(
          response['message']?.toString() ?? 'Invalid code. Please try again.',
          isSuccess: false,
        );
        // The backend ends this sign-in after too many wrong codes or when
        // it expires; send the user back to enter their password again.
        final msg = response['message']?.toString().toLowerCase() ?? '';
        if (msg.contains('sign in again') && mounted) {
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.pop(context);
        }
        return;
      }

      final data = response['data'];
      final accessToken = data is Map ? data['accessToken'] : null;
      final refreshToken = data is Map ? data['refreshToken'] : null;
      if (accessToken == null) {
        _showBanner('Sign-in failed. Please try again.', isSuccess: false);
        return;
      }

      await BiometricService.handleSignIn(widget.email);
      await ApiService.setAccessToken(accessToken.toString());
      if (refreshToken != null) {
        await ApiService.setRefreshToken(refreshToken.toString());
      }
      // Register this device for push notifications (best-effort).
      PushService.instance.registerWithBackend();

      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic>? user;
      final profileResponse = await ApiService.getCurrentUserProfile();
      if (profileResponse['status'] == 'success' &&
          profileResponse['data'] is Map) {
        user = Map<String, dynamic>.from(profileResponse['data'] as Map);
        final detailed = await ApiService.getUserById(
          (user['id'] ?? user['userId'])?.toString() ?? 'undefined',
        );
        if (detailed['status'] == 'success' && detailed['data'] != null) {
          await prefs.setString('userProfile', json.encode(detailed['data']));
        }
      } else if (data is Map && data['user'] is Map) {
        user = Map<String, dynamic>.from(data['user'] as Map);
      }

      if (user == null) {
        _showBanner('Failed to load user profile', isSuccess: false);
        return;
      }

      final rawId = user['id'] ?? user['userId'];
      final userId =
          rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;
      final role =
          (user['role'] ?? user['type'] ?? 'end_user').toString().toLowerCase();

      await prefs.setInt('user_id', userId);
      await prefs.setString('userType', role);
      await prefs.setString('email', user['email']?.toString() ?? '');
      await prefs.setString(
        'name',
        (user['name'] ?? user['first_name'] ?? '').toString(),
      );
      await prefs.setString('phone', user['phone']?.toString() ?? '');
      await prefs.setString('address', user['address']?.toString() ?? '');

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => _homeForRole(role, userId)),
        (route) => false,
      );
    } catch (e) {
      _showBanner('Verification failed: ${e.toString()}', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    final headerHeight = size.height * (_isSetup ? 0.26 : 0.30);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _surface,
        body: Stack(
          children: [
            // ── Fixed gradient header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _OtpHeader(
                height: headerHeight,
                topPad: topPad,
                title:
                    _isSetup
                        ? 'Set up two-factor authentication'
                        : 'Two-factor authentication',
              ),
            ),

            // ── Scrollable content
            Positioned.fill(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(top: headerHeight),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Container(
                  color: _surface,
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isSetup
                            ? 'Link an authenticator app'
                            : 'Enter authentication code',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isSetup
                            ? 'Your account now needs a code from Google '
                                'Authenticator or Microsoft Authenticator '
                                'each time you sign in. Link the app once to '
                                'continue.'
                            : 'Open Google Authenticator or Microsoft '
                                'Authenticator and enter the 6-digit code '
                                'for Ardent Starlink.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _inkSecondary,
                          height: 1.5,
                        ),
                      ),

                      if (_isSetup) ...[
                        const SizedBox(height: 22),
                        AuthenticatorLinkPanel(info: widget.setup!),
                      ],

                      const SizedBox(height: 28),

                      TotpCodeField(
                        controller: _codeController,
                        enabled: !_isLoading,
                        autofocus: !_isSetup,
                        onCompleted: (_) => _verifyOtp(),
                      ),

                      // Banner (success green / error red)
                      if (_bannerMessage != null) _buildBanner(),

                      const SizedBox(height: 28),

                      // Verify button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            disabledBackgroundColor: AppColors.brand.withOpacity(0.5),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: const StadiumBorder(),
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
                                  : Text(
                                    _isSetup ? 'Link and Sign In' : 'Verify Code',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Center(
                        child: Text(
                          'Lost access to your authenticator app?\n'
                          'Contact your administrator to reset it.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: _inkSecondary,
                            height: 1.5,
                          ),
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
  final String title;
  const _OtpHeader({
    required this.height,
    required this.topPad,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF133341), Color(0xFF0C2029)],
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
                      Icons.verified_user_outlined,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
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
