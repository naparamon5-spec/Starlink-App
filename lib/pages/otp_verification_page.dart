import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'end-user/home/home_screen.dart';

class OtpVerificationPage extends StatefulWidget {
  final String email;

  const OtpVerificationPage({super.key, required this.email});

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  bool _isLoading = false;
  String? _errorMessage;

  bool _canResend = false;
  int _resendSeconds = 30;
  Timer? _timer;

  String get _otp => _controllers.map((c) => c.text).join();

  static const Color primaryColor = Color(0xFF133343);

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _resendSeconds = 30;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds == 0) {
        setState(() => _canResend = true);
        timer.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _resendCode() async {
    try {
      final response = await ApiService.resendOtp({'email': widget.email});
      if (response['status'] == 'success') {
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP resent successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? "Failed to resend OTP"),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error resending OTP: $e")));
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 4) {
      setState(() => _errorMessage = "Enter complete 4-digit OTP");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.verifyOtp(widget.email, _otp);
      final data = response['data'];
      final accessToken = data?['accessToken'];
      final refreshToken = data?['refreshToken'];

      if (accessToken != null) {
        print('[DEBUG] OTP Verification: Storing tokens');
        // Store tokens
        await ApiService.setAccessToken(accessToken.toString());
        if (refreshToken != null) {
          await ApiService.setRefreshToken(refreshToken.toString());
        }

        // Get user profile using /api/v1/auth/me
        print('[DEBUG] OTP Verification: Loading user profile from /api/v1/auth/me');
        final profileResponse = await ApiService.getCurrentUserProfile();
        
        if (profileResponse['status'] == 'success' && profileResponse['data'] != null) {
          final user = profileResponse['data'];
          final userId = user['id'] ?? user['userId'];
          print('[DEBUG] OTP Verification: Profile loaded from /me - User ID: $userId');
          
          // Get detailed user profile using /api/v1/users/:id
          final userIdStr = userId?.toString() ?? 'undefined';
          print('[DEBUG] OTP Verification: Loading detailed profile from /api/v1/users/$userIdStr');
          final detailedProfileResponse = await ApiService.getUserById(userIdStr);
          
          if (detailedProfileResponse['status'] == 'success' && detailedProfileResponse['data'] != null) {
            final detailedUser = detailedProfileResponse['data'];
            print('[DEBUG] OTP Verification: Detailed profile loaded - Full data: $detailedUser');
            
            // Store detailed user data in SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('userProfile', json.encode(detailedUser));
            print('[DEBUG] OTP Verification: User profile stored in SharedPreferences');
          } else {
            print('[DEBUG] OTP Verification: Failed to load detailed profile: ${detailedProfileResponse['message']}');
          }
          
          // Store user info in SharedPreferences for backward compatibility
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userType', user['role'] ?? 'end_user');
          await prefs.setString('email', user['email'] ?? '');
          await prefs.setString('name', user['name'] ?? user['first_name'] ?? '');
          await prefs.setString('phone', user['phone'] ?? '');
          await prefs.setString('address', user['address'] ?? '');

          if (!mounted) return;

          if (userId != null) {
            print('[DEBUG] OTP Verification: Navigating to home screen');
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder:
                    (_) => HomeScreen(
                      userId: userId is int ? userId : int.tryParse(userId.toString()) ?? 0,
                      loginMessage: 'Login successful',
                    ),
              ),
              (route) => false,
            );
          } else {
            setState(() => _errorMessage = "Failed to get user ID");
          }
        } else {
          // Fallback to using user data from OTP response if available
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
            setState(() => _errorMessage = "Failed to load user profile");
          }
        }
      } else {
        setState(() => _errorMessage = "Invalid OTP");
      }
    } catch (e) {
      setState(() => _errorMessage = "OTP verification failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 60,
      height: 60,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        maxLength: 1,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[200],
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 3)
            _focusNodes[index + 1].requestFocus();
          if (value.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();
          if (_otp.length == 4) _verifyOtp();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Email Verification"),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.email, size: 80, color: primaryColor),
            const SizedBox(height: 20),
            const Text(
              "Enter the 4-digit code sent to your email",
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) => _buildOtpBox(index)),
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: primaryColor,
              ),
              child:
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                        "Verify OTP",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _canResend ? _resendCode : null,
              child: Text(
                _canResend ? "Resend Code" : "Resend in $_resendSeconds sec",
                style: TextStyle(
                  color: _canResend ? primaryColor : Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
