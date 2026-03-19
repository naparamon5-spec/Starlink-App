import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import 'reset_password.dart';

class VerificationCodeScreen extends StatefulWidget {
  final String email;

  const VerificationCodeScreen({super.key, required this.email});

  @override
  State<VerificationCodeScreen> createState() => _VerificationCodeScreenState();
}

class _VerificationCodeScreenState extends State<VerificationCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;
  int _resendAttempts = 0;
  bool _canResend = true;
  int _resendCooldown = 60;

  @override
  void initState() {
    super.initState();
    // Auto-focus the input field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _codeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
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
      print('Response data: $data'); // Debug print

      if (response.statusCode == 200) {
        if (data['status'] == 'success' || data['success'] == true) {
          String? token;

          // Try to get token from different possible locations in the response
          if (data.containsKey('data') &&
              data['data'] is Map<String, dynamic>) {
            final dataObj = data['data'] as Map<String, dynamic>;
            token =
                dataObj['resetToken']?.toString() ??
                dataObj['reset_token']?.toString() ??
                dataObj['token']?.toString();
          }

          // If not found in data object, try top level
          token ??=
              data['token']?.toString() ??
              data['reset_token']?.toString() ??
              data['resetToken']?.toString();

          if (token != null) {
            print('Token found: $token'); // Debug print
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
            print('No token found in response: $data'); // Debug print
            setState(() {
              _errorMessage =
                  'Unable to proceed with password reset. Please try again.';
            });
          }
        } else {
          final error = data['message'] as String? ?? data['error'] as String?;
          setState(() {
            if (error?.toLowerCase().contains('expired') ?? false) {
              _errorMessage =
                  'Verification code has expired. Please request a new one.';
              _codeController.clear();
              _canResend = true;
              _resendCooldown = 0;
            } else {
              _errorMessage = error ?? 'Invalid verification code';
            }
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to verify code. Please try again.';
        });
      }
    } catch (e) {
      print('Error during verification: $e'); // Debug print
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

      // Check if response is valid JSON
      Map<String, dynamic> data;
      try {
        data = json.decode(response.body) as Map<String, dynamic>;
      } catch (e) {
        print('Error parsing response: $e');
        print('Response status code: ${response.statusCode}');
        print('Response body: ${response.body}');

        setState(() {
          _errorMessage =
              'Server error: Unable to send verification code. Please contact support.';
        });
        return;
      }

      // Rest of the response handling
      if (response.statusCode == 200 &&
          (data['status'] == 'success' || data['success'] == true)) {
        setState(() {
          _resendAttempts++;
          _canResend = false;
          _codeController.clear();
        });

        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() {
              _resendCooldown--;
            });
            _startCooldownTimer();
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (data['message'] as String?) ??
                  'Verification code resent successfully',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        final error = data['message'] as String? ?? data['error'] as String?;
        setState(() {
          _errorMessage = error ?? 'Failed to resend verification code';
        });
      }
    } catch (e) {
      print('Error during resend: $e'); // Debug print
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startCooldownTimer() {
    if (_resendCooldown > 0) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _resendCooldown--;
          });
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
    final theme = Theme.of(context);
    final primaryColor = const Color(0xFF133343);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Code'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.verified_user, size: 64, color: primaryColor),
                const SizedBox(height: 20),
                Text(
                  'Enter Verification Code',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Please enter the verification code sent to ${widget.email}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 25),
                TextFormField(
                  controller: _codeController,
                  focusNode: _codeFocusNode,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Enter 6-digit code',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    if (value.length == 6) {
                      _verifyCode();
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the verification code';
                    }
                    if (value.length != 6) {
                      return 'Code must be 6 digits';
                    }
                    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
                      return 'Code must contain only numbers';
                    }
                    return null;
                  },
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
                const SizedBox(height: 25),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text(
                              'Verify Code',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _canResend ? _resendCode : null,
                  child: Text(
                    _canResend
                        ? 'Resend Code'
                        : 'Resend Code in $_resendCooldown seconds',
                    style: TextStyle(
                      color: _canResend ? primaryColor : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
