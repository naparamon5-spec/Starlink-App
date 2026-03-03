import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'end-user/home/home_screen.dart';
import 'customer/home/customer_home_screen.dart';
import 'admin/admin_home_screen.dart';
import 'biller/biller_home_screen.dart';
import 'agent/agent_home_screen.dart';
import 'forgot_password.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'otp_verification_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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

  bool isEmailValid(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Returns the correct home screen widget based on the user's role.
  Widget _getScreenForRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return const AdminHomeScreen();
      case 'biller':
        return const BillerApp();
      case 'agent':
        return const AgentApp();
      case 'customer':
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

      print('Login response: $response');

      if (response.containsKey('userId') && response['flag'] == false) {
        // This is an end_user — send to OTP verification
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationPage(email: _emailController.text),
          ),
        );
      } else if (response.containsKey('accessToken')) {
        print('[DEBUG] Login: Login successful, storing tokens');

        final accessToken = response['accessToken'];
        final refreshToken = response['refreshToken'];

        if (accessToken != null) {
          await ApiService.setAccessToken(accessToken.toString());
          print('[DEBUG] Login: Access token stored');
        }
        if (refreshToken != null) {
          await ApiService.setRefreshToken(refreshToken.toString());
          print('[DEBUG] Login: Refresh token stored');
        }

        // Get user profile using /api/v1/auth/me
        print('[DEBUG] Login: Loading user profile from /api/v1/auth/me');
        final profileResponse = await ApiService.getCurrentUserProfile();

        if (profileResponse['status'] == 'success' &&
            profileResponse['data'] != null) {
          final userData = profileResponse['data'];
          print(
            '[DEBUG] Login: Profile loaded — User ID: ${userData['id']}, '
            'Email: ${userData['email']}, Role: ${userData['role']}',
          );

          // Get detailed user profile using /api/v1/users/:id
          final userId = userData['id']?.toString() ?? 'undefined';
          print('[DEBUG] Login: Loading detailed profile for user $userId');
          final detailedProfileResponse = await ApiService.getUserById(userId);

          if (detailedProfileResponse['status'] == 'success' &&
              detailedProfileResponse['data'] != null) {
            final detailedUserData = detailedProfileResponse['data'];
            print('[DEBUG] Login: Detailed profile loaded — $detailedUserData');

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('userProfile', json.encode(detailedUserData));
            print('[DEBUG] Login: User profile stored in SharedPreferences');
          } else {
            print(
              '[DEBUG] Login: Failed to load detailed profile: '
              '${detailedProfileResponse['message']}',
            );
          }

          // Determine role — prefer 'role', fall back to 'type'
          final userRole =
              (userData['role'] ?? userData['type'] ?? 'customer')
                  .toString()
                  .toLowerCase();

          print('[DEBUG] Login: Navigating based on role: $userRole');

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => _getScreenForRole(userRole)),
          );
        } else {
          print(
            '[DEBUG] Login: Failed to load profile from /me: '
            '${profileResponse['message']}',
          );

          // Fallback: use user data bundled in the login response
          if (response.containsKey('user')) {
            final userData = response['user'];
            final userRole =
                (userData['role'] ?? userData['type'] ?? 'customer')
                    .toString()
                    .toLowerCase();

            print('[DEBUG] Login: Using fallback user data, role: $userRole');

            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => _getScreenForRole(userRole)),
            );
          } else {
            setState(
              () =>
                  _errorMessage =
                      'Failed to load user profile. Please try again.',
            );
          }
        }
      } else {
        setState(
          () =>
              _errorMessage =
                  response['message'] ?? 'Invalid login credentials',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              autovalidateMode:
                  _showValidation
                      ? AutovalidateMode.always
                      : AutovalidateMode.disabled,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 45),
                  SvgPicture.asset('assets/images/logo_full.svg', height: 50),
                  const SizedBox(height: 24),
                  const Text(
                    'Sign in to your account',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 50),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Email Address',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Enter your email address',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Color(0xFF133343)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 1.5,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 1.5,
                        ),
                      ),
                      errorStyle: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                      errorMaxLines: 2,
                      errorText: _emailError,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email address';
                      }
                      if (!isEmailValid(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(color: Color(0xFF133343)),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 1.5,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 1.5,
                        ),
                      ),
                      errorStyle: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                      ),
                      errorMaxLines: 2,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      errorText: _passwordError,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(fontSize: 14, color: Colors.black),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _isAgreedToTerms,
                        onChanged: (value) {
                          setState(() {
                            _isAgreedToTerms = value ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: RichText(
                          text: const TextSpan(
                            text: "I've read and agreed to ",
                            style: TextStyle(color: Colors.black, fontSize: 14),
                            children: [
                              TextSpan(
                                text: 'User Agreement',
                                style: TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_showValidation && !_isAgreedToTerms)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Please agree to the Terms and Privacy Policy',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: const Color(0xFF133343),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : const Text(
                              'Log in',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
