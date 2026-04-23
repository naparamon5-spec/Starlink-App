import 'dart:convert';
import 'dart:io' show HttpClient, X509Certificate;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/ssl_config.dart';

class ApiService {
  static String get baseUrl => 'https://starlink-api.ardentnetworks.com.ph/api';
  static bool _isRefreshingToken = false;

  static http.Client get _client {
    if (kIsWeb) return http.Client();
    final httpClient =
        HttpClient()
          ..connectionTimeout = const Duration(seconds: 15)
          ..badCertificateCallback = (cert, host, port) => true; // dev only
    return IOClient(httpClient);
  }

  // ─── Core authorized GET helper ───────────────────────────────────────────
  static Future<Map<String, dynamic>> _authorizedGet(
    String path, {
    Map<String, String>? queryParameters,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      final accessToken = await getValidAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        return {
          'status': 'error',
          'message': 'No access token available. Please login again.',
        };
      }

      Uri uri = Uri.parse('$baseUrl$path');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }

      Future<http.Response> doRequest(String token) => _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            timeout,
            onTimeout:
                () => http.Response(
                  json.encode({
                    'status': 'error',
                    'message': 'Connection timed out.',
                  }),
                  408,
                ),
          );

      http.Response response = await doRequest(accessToken);

      if (response.statusCode == 401) {
        final refreshResult = await refreshToken();
        if (refreshResult['status'] == 'success' &&
            refreshResult['accessToken'] != null) {
          response = await doRequest(refreshResult['accessToken'].toString());
        } else {
          await clearTokens();
          return {
            'status': 'error',
            'message': 'Session expired. Please login again.',
          };
        }
      }

      dynamic decoded;
      try {
        decoded = json.decode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          final data = decoded.containsKey('data') ? decoded['data'] : decoded;
          return {
            'status': 'success',
            'data': data,
            'message': decoded['message']?.toString() ?? 'Success',
            'raw': decoded,
          };
        }
        if (decoded is List) {
          return {'status': 'success', 'data': decoded, 'raw': decoded};
        }
        return {'status': 'success', 'data': decoded, 'raw': decoded};
      }

      if (response.statusCode == 401) {
        await clearTokens();
        return {
          'status': 'error',
          'message': 'Session expired. Please login again.',
          'statusCode': response.statusCode,
        };
      }

      String msg = 'Server error: ${response.statusCode}';
      if (decoded is Map) {
        final m = decoded['message'] ?? decoded['Message'];
        if (m != null) msg = m.toString();
      }
      return {
        'status': 'error',
        'message': msg,
        'statusCode': response.statusCode,
        'raw': decoded,
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> _authorizedGetJson(
    String path, {
    Map<String, String>? queryParameters,
  }) => _authorizedGet(path, queryParameters: queryParameters);

  static Future<Map<String, dynamic>> _getV1WithAuth(
    String path, {
    Duration timeout = const Duration(seconds: 20),
  }) => _authorizedGet(path, timeout: timeout);

  static bool _isRoleAccessError(Map<String, dynamic> result) {
    final msg = result['message']?.toString().toLowerCase() ?? '';
    final statusCode = result['statusCode']?.toString() ?? '';
    return msg.contains('role') ||
        msg.contains('forbidden') ||
        msg.contains('not authorized') ||
        msg.contains('not allowed') ||
        msg.contains('authentication') ||
        statusCode == '401' ||
        statusCode == '403' ||
        statusCode == '500';
  }

  static Map<String, dynamic> _extractUserData(dynamic source) {
    if (source is Map<String, dynamic>) {
      final nested = source['data'];
      if (nested is Map<String, dynamic>) return nested;
      return source;
    }
    return <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> _getCurrentUserContext() async {
    final me = await getMe();
    if (me['status'] == 'success') {
      final data = _extractUserData(me['data']);
      return {'status': 'success', 'data': data, 'raw': me};
    }
    return me;
  }

  static Map<String, dynamic> _successListResult(
    dynamic wrapper, {
    dynamic raw,
    String successMessage = 'Success',
  }) {
    List<dynamic> items = [];
    Map<String, dynamic>? pagination;

    if (wrapper is Map<String, dynamic>) {
      final nestedData = wrapper['data'];
      final nestedPagination = wrapper['pagination'];

      if (nestedData is List) {
        items = List<dynamic>.from(nestedData);
      } else if (nestedData is Map<String, dynamic>) {
        final deepData = nestedData['data'];
        final deepPagination = nestedData['pagination'];

        if (deepData is List) {
          items = List<dynamic>.from(deepData);
        }

        if (deepPagination is Map<String, dynamic>) {
          pagination = Map<String, dynamic>.from(deepPagination);
        }
      }

      if (pagination == null && nestedPagination is Map<String, dynamic>) {
        pagination = Map<String, dynamic>.from(nestedPagination);
      }
    } else if (wrapper is List) {
      items = List<dynamic>.from(wrapper);
    }

    return {
      'status': 'success',
      'message': successMessage,
      'data': items,
      if (pagination != null) 'pagination': pagination,
      'raw': raw ?? wrapper,
    };
  }

  static String? _pickFirstNonEmpty(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null &&
          value.isNotEmpty &&
          value != 'null' &&
          value != 'undefined') {
        return value;
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>> _getSubscriptionsForCurrentUser() async {
    final profile = await _getCurrentUserContext();
    if (profile['status'] != 'success') {
      return Map<String, dynamic>.from(profile);
    }

    final data = _extractUserData(profile['data']);
    final role =
        (data['role'] ?? data['user_role'] ?? data['type'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    final euCode = _pickFirstNonEmpty(data, [
      'eu_code',
      'euCode',
      'end_user_code',
      'endUserCode',
      'com_eu_code',
      'company',
      'company_code',
    ]);

    final customerCode = _pickFirstNonEmpty(data, [
      'customer_code',
      'customerCode',
      'company_code',
      'companyCode',
      'com_eu_code',
      'company',
      'customer',
    ]);

    if (role == 'admin' || role == 'agent') {
      try {
        final list = await getSubscriptions();
        return {'status': 'success', 'data': list, 'raw': list};
      } catch (e) {
        return {
          'status': 'error',
          'message': e.toString().replaceAll('Exception: ', ''),
        };
      }
    }

    if (euCode != null) {
      final byEu = await _getV1WithAuth('/v1/subscriptions/end-user/$euCode');
      if (byEu['status'] == 'success') return byEu;
    }

    if (customerCode != null) {
      final byCustomer = await _getV1WithAuth(
        '/v1/subscriptions/customer/$customerCode',
      );
      if (byCustomer['status'] == 'success') return byCustomer;
    }

    try {
      final list = await getSubscriptions();
      return {'status': 'success', 'data': list, 'raw': list};
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // ─── Token management ─────────────────────────────────────────────────────

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refreshToken');
  }

  static Future<void> setAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', token);
  }

  static Future<void> setRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('refreshToken', token);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
  }

  static Future<Map<String, dynamic>> refreshToken() async {
    if (_isRefreshingToken) {
      // Avoid parallel refresh calls racing and wiping tokens unexpectedly.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final latestToken = await getAccessToken();
      if (latestToken != null && latestToken.isNotEmpty) {
        return {'status': 'success', 'accessToken': latestToken};
      }
    }

    try {
      _isRefreshingToken = true;
      final refreshTokenValue = await getRefreshToken();
      if (refreshTokenValue == null || refreshTokenValue.isEmpty) {
        throw Exception('No refresh token available');
      }
      final response = await _client
          .post(
            Uri.parse('$baseUrl/v1/auth/refresh'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Cookie': 'refreshToken=$refreshTokenValue',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String? newAccessToken;
        String? newRefreshToken;

        if (data is Map<String, dynamic>) {
          newAccessToken =
              data['accessToken']?.toString() ??
              (data['data'] is Map<String, dynamic>
                  ? (data['data']['accessToken']?.toString())
                  : null);
          newRefreshToken =
              data['refreshToken']?.toString() ??
              (data['data'] is Map<String, dynamic>
                  ? (data['data']['refreshToken']?.toString())
                  : null);
        }

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await setAccessToken(newAccessToken);
          if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
            await setRefreshToken(newRefreshToken);
          }
          return {'status': 'success', 'accessToken': newAccessToken};
        }
        throw Exception('No access token in refresh response');
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await clearTokens();
      }
      throw Exception(
        response.statusCode == 401 || response.statusCode == 403
            ? 'Session expired. Please login again.'
            : 'Token refresh failed: ${response.statusCode}',
      );
    } catch (e) {
      final message = e.toString();
      final isPermanentAuthError =
          message.contains('No refresh token available') ||
          message.contains('Session expired. Please login again.');
      if (isPermanentAuthError) {
        await clearTokens();
      }
      return {'status': 'error', 'message': message};
    } finally {
      _isRefreshingToken = false;
    }
  }

  static Future<String?> getValidAccessToken() async {
    final token = await getAccessToken();
    if (token != null && token.isNotEmpty) return token;
    final result = await refreshToken();
    if (result['status'] == 'success') return result['accessToken'];
    return null;
  }

  // ─── Auth ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/test_connection.php'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout:
                () => http.Response(
                  json.encode({
                    'status': 'error',
                    'message':
                        'Connection timed out. Please check your internet connection.',
                  }),
                  408,
                ),
          );
      return json.decode(response.body);
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Connection error: $e',
        'baseUrl': baseUrl,
      };
    }
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/v1/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = json.decode(response.body);
      if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
        data.addAll(Map<String, dynamic>.from(data['data']));
      }
      if (!data.containsKey('status') && response.statusCode == 200) {
        data['status'] = 'success';
      }
      if (data.containsKey('user')) {
        if (data['user'] == null) {
          throw Exception('Invalid response: user data missing');
        }
        return data;
      }
      if (data.containsKey('userId') && data['flag'] == false) return data;
      throw Exception('Unexpected response format: ${response.body}');
    } catch (e) {
      return {'status': 'error', 'message': e.toString(), 'baseUrl': baseUrl};
    }
  }

  static Future<dynamic> verifyOtp(String email, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to verify OTP');
  }

  static Future<Map<String, dynamic>> resendOtp(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/v1/auth/resend-otp'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return data;
        return {
          'status': 'error',
          'message': data['message'] ?? 'Failed to resend OTP',
        };
      }
      return {
        'status': 'error',
        'message': 'Server error: ${response.statusCode}',
      };
    } catch (e) {
      return {'status': 'error', 'message': 'Failed to resend OTP: $e'};
    }
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/v1/auth/request-reset-password'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({'email': email}),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout:
                () => http.Response(
                  json.encode({
                    'status': 'error',
                    'message': 'Connection timed out. Please try again.',
                  }),
                  408,
                ),
          );

      Map<String, dynamic>? data;
      try {
        data = json.decode(response.body) as Map<String, dynamic>?;
      } catch (_) {}

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (data != null) {
          if (data['status'] == 'success' || data['success'] == true) {
            return data;
          }
          if (data['message'] is String) {
            return {
              'status': 'success',
              'message': data['message'],
              'raw': data,
            };
          }
        }
        return {
          'status': 'success',
          'message': 'Password reset request sent. Please check your email.',
          'details': response.body,
        };
      }

      final serverMsg =
          (data != null && data['message'] is String)
              ? data['message'] as String
              : 'Server error: ${response.statusCode}';
      return {
        'status': 'error',
        'message': serverMsg,
        'details': response.body,
      };
    } catch (e) {
      if (e.toString().contains('CERTIFICATE_VERIFY_FAILED')) {
        final msg =
            SSLConfig.isDevelopment
                ? 'SSL Certificate verification failed in development mode.'
                : 'SSL Certificate verification failed. Please contact support.';
        return {'status': 'error', 'message': msg, 'details': e.toString()};
      }
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // GET /api/v1/auth/me
  static Future<Map<String, dynamic>> getMe() async =>
      _getV1WithAuth('/v1/auth/me');

  // Alias kept for backward-compat
  static Future<Map<String, dynamic>> getCurrentUserProfile() async =>
      _getV1WithAuth('/v1/auth/me');

  // ─── User endpoints ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getUsersList() async =>
      _authorizedGet('/v1/users');

  static Future<Map<String, dynamic>> getUserById(String userId) async {
    final uid =
        (userId.isEmpty || userId == 'null' || userId == 'undefined')
            ? 'undefined'
            : userId;
    return _authorizedGet('/v1/users/$uid');
  }

  static Future<Map<String, dynamic>> getUserById2(String id) =>
      getUserById(id);

  static Future<Map<String, dynamic>> getUserRolesList() async =>
      _authorizedGet('/v1/users/list/role');

  static Future<List<dynamic>> getContacts({String? bearerToken}) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/v1/users/list/contact/'),
            headers: {
              'Accept': 'application/json',
              if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout:
                () => http.Response(
                  json.encode({
                    'status': 'error',
                    'message': 'Connection timed out.',
                  }),
                  408,
                ),
          );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] is List) {
          return (data['data'] as List).map((contact) {
            if (contact is Map<String, dynamic>) {
              return {
                ...contact,
                'id': int.tryParse(contact['id'].toString()) ?? contact['id'],
              };
            }
            return contact;
          }).toList();
        }
        throw Exception(data['message'] ?? 'Failed to fetch contacts');
      }
      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching contacts: $e');
    }
  }

  static Future<Map<String, dynamic>> getUsersByCompanyCode(
    String companyCode,
  ) async => _getV1WithAuth('/v1/users/company/$companyCode');

  // FIX: was /v1/users/my/profile/ (404) — now correctly points to /v1/auth/me
  static Future<Map<String, dynamic>> getMyProfile() async =>
      _getV1WithAuth('/v1/auth/me');

  static Future<Map<String, dynamic>> createUser(
    Map<String, dynamic> payload,
  ) async {
    try {
      final accessToken = await getValidAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        return {
          'status': 'error',
          'message': 'No access token available. Please login again.',
        };
      }

      Future<http.Response> doRequest(String token) => _client
          .post(
            Uri.parse('$baseUrl/v1/users/'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(payload),
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout:
                () => http.Response(
                  json.encode({
                    'status': 'error',
                    'message': 'Connection timed out. Please try again.',
                  }),
                  408,
                ),
          );

      http.Response response = await doRequest(accessToken);
      if (response.statusCode == 401) {
        final r = await refreshToken();
        if (r['status'] == 'success' && r['accessToken'] != null) {
          response = await doRequest(r['accessToken'].toString());
        } else {
          await clearTokens();
          return {
            'status': 'error',
            'message': 'Session expired. Please login again.',
          };
        }
      }

      dynamic decoded;
      try {
        decoded = json.decode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          return {
            'status': decoded['status']?.toString() ?? 'success',
            'message': decoded['message']?.toString() ?? 'User created.',
            'data': decoded['data'],
            'raw': decoded,
          };
        }
        return {'status': 'success', 'message': 'User created.'};
      }

      String msg = 'Server error: ${response.statusCode}';
      if (decoded is Map) {
        final m = decoded['message'] ?? decoded['Message'];
        if (m != null) msg = m.toString();
      }
      return {'status': 'error', 'message': msg, 'raw': decoded};
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> updateUser(
    String id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final accessToken = await getValidAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        return {
          'status': 'error',
          'message': 'No access token available. Please login again.',
        };
      }

      Future<http.Response> doRequest(String token) => _client
          .put(
            Uri.parse('$baseUrl/v1/users/$id'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(payload),
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout:
                () => http.Response(
                  json.encode({
                    'status': 'error',
                    'message': 'Connection timed out. Please try again.',
                  }),
                  408,
                ),
          );

      http.Response response = await doRequest(accessToken);
      if (response.statusCode == 401) {
        final r = await refreshToken();
        if (r['status'] == 'success' && r['accessToken'] != null) {
          response = await doRequest(r['accessToken'].toString());
        } else {
          await clearTokens();
          return {
            'status': 'error',
            'message': 'Session expired. Please login again.',
          };
        }
      }

      dynamic decoded;
      try {
        decoded = json.decode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          return {
            'status': decoded['status']?.toString() ?? 'success',
            'message': decoded['message']?.toString() ?? 'User updated.',
            'data': decoded['data'],
            'raw': decoded,
          };
        }
        return {'status': 'success', 'message': 'User updated.'};
      }

      String msg = 'Server error: ${response.statusCode}';
      if (decoded is Map) {
        final m = decoded['message'] ?? decoded['Message'];
        if (m != null) msg = m.toString();
      }
      return {'status': 'error', 'message': msg, 'raw': decoded};
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> deactivateUser(String id) async {
    try {
      final accessToken = await getValidAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        return {
          'status': 'error',
          'message': 'No access token available. Please login again.',
        };
      }

      Future<http.Response> doRequest(String token) => _client
          .put(
            Uri.parse('$baseUrl/v1/users/deactivate/$id'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout:
                () => http.Response(
                  json.encode({
                    'status': 'error',
                    'message': 'Connection timed out.',
                  }),
                  408,
                ),
          );

      http.Response response = await doRequest(accessToken);
      if (response.statusCode == 401) {
        final r = await refreshToken();
        if (r['status'] == 'success' && r['accessToken'] != null) {
          response = await doRequest(r['accessToken'].toString());
        } else {
          await clearTokens();
          return {
            'status': 'error',
            'message': 'Session expired. Please login again.',
          };
        }
      }

      dynamic decoded;
      try {
        decoded = json.decode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          return {
            'status': decoded['status']?.toString() ?? 'success',
            'message': decoded['message']?.toString() ?? 'User deactivated.',
            'data': decoded['data'],
            'raw': decoded,
          };
        }
        return {'status': 'success', 'message': 'User deactivated.'};
      }

      String msg = 'Server error: ${response.statusCode}';
      if (decoded is Map) {
        final m = decoded['message'] ?? decoded['Message'];
        if (m != null) msg = m.toString();
      }
      return {'status': 'error', 'message': msg, 'raw': decoded};
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> activateUser(String id) async {
    try {
      final accessToken = await getValidAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        return {
          'status': 'error',
          'message': 'No access token available. Please login again.',
        };
      }

      Future<http.Response> doRequest(String token) => _client
          .put(
            Uri.parse('$baseUrl/v1/users/activate/$id'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout:
                () => http.Response(
                  json.encode({
                    'status': 'error',
                    'message': 'Connection timed out.',
                  }),
                  408,
                ),
          );

      http.Response response = await doRequest(accessToken);
      if (response.statusCode == 401) {
        final r = await refreshToken();
        if (r['status'] == 'success' && r['accessToken'] != null) {
          response = await doRequest(r['accessToken'].toString());
        } else {
          await clearTokens();
          return {
            'status': 'error',
            'message': 'Session expired. Please login again.',
          };
        }
      }

      dynamic decoded;
      try {
        decoded = json.decode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          return {
            'status': decoded['status']?.toString() ?? 'success',
            'message': decoded['message']?.toString() ?? 'User activated.',
            'data': decoded['data'],
            'raw': decoded,
          };
        }
        return {'status': 'success', 'message': 'User activated.'};
      }

      String msg = 'Server error: ${response.statusCode}';
      if (decoded is Map) {
        final m = decoded['message'] ?? decoded['Message'];
        if (m != null) msg = m.toString();
      }
      return {'status': 'error', 'message': msg, 'raw': decoded};
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // Legacy — kept for backward-compat but routes through new API
  static Future<Map<String, dynamic>> getCurrentUser(int userId) async =>
      _getV1WithAuth('/v1/auth/me');

  static Future<Map<String, dynamic>> updateUserProfile(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api.php?action=update_user_profile'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(data),
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updatePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api.php?action=update_password'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'user_id': userId,
              'current_password': currentPassword,
              'new_password': newPassword,
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout:
                () => http.Response(
                  json.encode({
                    'status': 'error',
                    'message': 'Connection timed out. Please try again.',
                  }),
                  408,
                ),
          );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' || data['success'] == true) return data;
        throw Exception(data['message'] ?? 'Failed to update password');
      }
      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  // ─── End-user endpoints ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getEndUserListAll() async =>
      _authorizedGet('/v1/end-user/list/all');

  static Future<Map<String, dynamic>> getEndUsersPaginated({
    int page = 1,
    int limit = 10,
    String search = '',
  }) async {
    final encodedSearch = Uri.encodeQueryComponent(search);
    final result = await _getV1WithAuth(
      '/v1/end-user/paginated?page=$page&limit=$limit&search=$encodedSearch',
    );
    if (result['status'] != 'success') return Map<String, dynamic>.from(result);

    return _successListResult(
      result['data'],
      raw: result['raw'],
      successMessage: result['message']?.toString() ?? 'Success',
    );
  }

  static Future<Map<String, dynamic>> getEndUserById(String euCode) async =>
      _getV1WithAuth('/v1/end-user/$euCode');

  static Future<Map<String, dynamic>> createEndUser(
    Map<String, dynamic> payload,
  ) async {
    try {
      final accessToken = await getValidAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        return {
          'status': 'error',
          'message': 'No access token available. Please login again.',
        };
      }

      Future<http.Response> doRequest(String token) => _client
          .post(
            Uri.parse('$baseUrl/v1/end-user/create'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(payload),
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout:
                () => http.Response(
                  json.encode({
                    'status': 'error',
                    'message': 'Connection timed out. Please try again.',
                  }),
                  408,
                ),
          );

      http.Response response = await doRequest(accessToken);
      if (response.statusCode == 401) {
        final r = await refreshToken();
        if (r['status'] == 'success' && r['accessToken'] != null) {
          response = await doRequest(r['accessToken'].toString());
        } else {
          await clearTokens();
          return {
            'status': 'error',
            'message': 'Session expired. Please login again.',
          };
        }
      }

      dynamic decoded;
      try {
        decoded = json.decode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          return {
            'status': decoded['status']?.toString() ?? 'success',
            'message': decoded['message']?.toString() ?? 'End user created.',
            'data': decoded['data'],
            'raw': decoded,
          };
        }
        return {'status': 'success', 'message': 'End user created.'};
      }

      String msg = 'Server error: ${response.statusCode}';
      if (decoded is Map) {
        final m = decoded['message'] ?? decoded['Message'];
        if (m != null) msg = m.toString();
      }
      return {'status': 'error', 'message': msg, 'raw': decoded};
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // FIX: was hitting legacy api.php — now uses v1 API
  static Future<Map<String, dynamic>> getEndUserByUserId(int userId) async =>
      _getV1WithAuth('/v1/auth/me');

  // ─── Customer endpoints ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getCustomersListAll() async =>
      _authorizedGet('/v1/customers/list/all');

  static Future<Map<String, dynamic>> getCustomersPaginated({
    int page = 1,
    int limit = 10,
    String search = '',
  }) async {
    final encodedSearch = Uri.encodeQueryComponent(search);
    return _getV1WithAuth(
      '/v1/customers/paginated?page=$page&limit=$limit&search=$encodedSearch',
    );
  }

  static Future<Map<String, dynamic>> getCustomerById(String id) async =>
      _getV1WithAuth('/v1/customers/$id');

  /// Returns subscriptions for a given customer code.
  ///
  /// Endpoint: `/api/v1/subscriptions/customer/:id`
  /// where `id` is the customer code.
  static Future<Map<String, dynamic>> getCustomers(String customerCode) async =>
      _getV1WithAuth('/v1/subscriptions/customer/$customerCode');

  /// Endpoint: `/api/v1/subscriptions/end-user/:id`
  /// where `id` is the end-user (EU) code.
  static Future<Map<String, dynamic>> getContactsByEuCode(
    String euCode,
  ) async => _getV1WithAuth('/v1/subscriptions/end-user/$euCode');

  // ─── Ticket endpoints ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getTickets({
    int page = 1,
    int limit = 10,
    String? status,
    String? ticketType,
    String? createdBy,
    String? assignedBy,
    String? requestedBy,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (ticketType != null && ticketType.isNotEmpty)
          'ticket_type': ticketType,
        if (createdBy != null && createdBy.isNotEmpty) 'created_by': createdBy,
        if (assignedBy != null && assignedBy.isNotEmpty)
          'assigned_by': assignedBy,
        if (requestedBy != null && requestedBy.isNotEmpty)
          'requested_by': requestedBy,
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final baseResult = await _authorizedGetJson(
        '/v1/tickets',
        queryParameters: queryParams,
      );
      if (baseResult['status'] != 'success') {
        return Map<String, dynamic>.from(baseResult);
      }

      return _successListResult(
        baseResult['data'],
        raw: baseResult['raw'],
        successMessage: baseResult['message']?.toString() ?? 'Success',
      );
    } catch (e) {
      throw Exception('Error fetching tickets: $e');
    }
  }

  static Future<Map<String, dynamic>> getMyOpenTickets() async =>
      _getV1WithAuth('/v1/tickets/mine/open');
  static Future<Map<String, dynamic>> getMyInProgressTickets() async =>
      _getV1WithAuth('/v1/tickets/mine/in-progress');
  static Future<Map<String, dynamic>> getMyResolvedTickets() async =>
      _getV1WithAuth('/v1/tickets/mine/resolved');
  static Future<Map<String, dynamic>> getMyClosedTickets() async =>
      _getV1WithAuth('/v1/tickets/mine/closed');
  static Future<Map<String, dynamic>> getRecentTicketActivity() async =>
      _getV1WithAuth('/v1/tickets/recent/activity');

  static Future<Map<String, dynamic>> getTicketById(String ticketId) async {
    final result = await _authorizedGetJson('/v1/tickets/$ticketId');
    if (result['status'] != 'success') return Map<String, dynamic>.from(result);
    final data = result['data'];
    return {
      'status': 'success',
      'data': data is Map ? Map<String, dynamic>.from(data) : data,
      'raw': result['raw'],
    };
  }

  static Future<Map<String, dynamic>> createTicket(
    Map<String, dynamic> ticket,
  ) async {
    return createTicketNamed(
      description: ticket['description']?.toString() ?? '',
      ticketType:
          ticket['ticket_type']?.toString() ?? ticket['type']?.toString() ?? '',
      subscriptionId:
          ticket['subscription_id']?.toString() ??
          ticket['subscription']?.toString() ??
          '',
      contact: ticket['contact']?.toString() ?? '',
      nickname:
          ticket['subject']?.toString() ??
          ticket['contact_name']?.toString() ??
          '',
      bearerToken: ticket['bearer_token']?.toString(),
      attachments:
          ticket['attachments'] != null
              ? List<Map<String, dynamic>>.from(
                (ticket['attachments'] as List).map(
                  (a) => Map<String, dynamic>.from(a as Map),
                ),
              )
              : null,
    );
  }

  static Future<Map<String, dynamic>> createTicketNamed({
    required String description,
    required String ticketType,
    required String subscriptionId,
    required String contact,
    required String nickname,
    String? bearerToken,
    List<Map<String, dynamic>>? attachments,
  }) async {
    try {
      if (description.isEmpty ||
          ticketType.isEmpty ||
          subscriptionId.isEmpty ||
          contact.isEmpty) {
        throw Exception('Missing required fields');
      }
      final token = bearerToken ?? await getValidAccessToken();
      if (token == null || token.isEmpty) {
        return {
          'status': 'error',
          'message': 'No access token available. Please login again.',
          'data': null,
        };
      }

      List<Map<String, dynamic>> processedAttachments = [];
      if (attachments != null) {
        for (var a in attachments) {
          processedAttachments.add({
            'name': a['name'],
            'type': a['type'] ?? 'application/octet-stream',
            'size': a['size'],
            'data': a['data'],
          });
        }
      }

      final safeNickname =
          nickname.trim().isNotEmpty ? nickname.trim() : subscriptionId.trim();
      final response = await _client
          .post(
            Uri.parse('$baseUrl/v1/tickets/'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'description': description,
              'ticket_type': ticketType,
              'subscription_id': subscriptionId,
              'contact': contact,
              'subject': '$safeNickname - $ticketType',
              'attachments': processedAttachments,
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout:
                () => http.Response(
                  json.encode({
                    'status': 'error',
                    'message': 'Connection timed out. Please try again.',
                  }),
                  408,
                ),
          );

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        data['data'] = {
          ...?data['data'],
          'status': 'open',
          'created_at': DateTime.now().toIso8601String(),
          'attachments': processedAttachments,
          'description': description,
          'ticket_type': ticketType,
          'subscription_id': subscriptionId,
          'contact': contact,
        };
        return data;
      }
      throw Exception(data['message'] ?? 'Failed to create ticket');
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> updateTicketStatus(
    String ticketId,
    String newStatus,
  ) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/api.php?action=update_ticket_status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'ticket_id': ticketId, 'status': newStatus}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return data;
        throw Exception(data['message'] ?? 'Failed to update ticket status');
      }
      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Failed to update ticket status: $e');
    }
  }

  static Future<Map<String, dynamic>> getTicketCategories() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/ticket-categories'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) return json.decode(response.body);
      throw Exception('Failed to load ticket categories');
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  static Future<Map<String, dynamic>> getCategories({
    String? bearerToken,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/v1/tickets/list/categories'),
            headers: {
              'Accept': 'application/json',
              if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout:
                () => http.Response(
                  json.encode({
                    'status': 'error',
                    'message': 'Connection timed out.',
                  }),
                  408,
                ),
          );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) return data;
        if (data is List) return {'status': 'success', 'data': data};
        return {'status': 'error', 'message': 'Unexpected response format'};
      }
      return {
        'status': 'error',
        'message': 'Server error: ${response.statusCode}',
      };
    } catch (e) {
      return {'status': 'error', 'message': 'Error fetching categories: $e'};
    }
  }

  static Future<Map<String, dynamic>> getTicketFilters({
    String? bearerToken,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/v1/tickets/list/filters'),
            headers: {
              'Accept': 'application/json',
              if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout:
                () => http.Response(
                  json.encode({
                    'status': 'error',
                    'message': 'Connection timed out.',
                  }),
                  408,
                ),
          );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final data = decoded is Map<String, dynamic> ? decoded['data'] : null;
        if (data is Map<String, dynamic>) {
          return {
            'status': 'success',
            'statuses': data['statuses'] ?? [],
            'ticket_types': data['ticket_types'] ?? [],
            'created_by': data['created_by'] ?? [],
            'assigned_by': data['assigned_by'] ?? [],
            'raw': decoded,
          };
        }
        return {
          'status': 'error',
          'message':
              (decoded is Map<String, dynamic>)
                  ? decoded['message'] ?? 'Failed to fetch ticket filters'
                  : 'Failed to fetch ticket filters',
          'raw': decoded,
        };
      }
      return {
        'status': 'error',
        'message': 'Server error: ${response.statusCode}',
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Error fetching ticket filters: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> getTicketActivities(
    String ticketId,
  ) async {
    final result = await _authorizedGetJson('/v1/activities/$ticketId');
    if (result['status'] != 'success') return Map<String, dynamic>.from(result);
    return {'status': 'success', 'data': result['data'], 'raw': result['raw']};
  }

  static Future<Map<String, dynamic>> getTicketAttachments(
    String ticketId,
  ) async {
    final result = await _authorizedGetJson('/v1/attachments/$ticketId');
    if (result['status'] != 'success') return Map<String, dynamic>.from(result);
    return {'status': 'success', 'data': result['data'], 'raw': result['raw']};
  }

  static Future<Map<String, dynamic>> downloadAttachment(
    String attachmentId,
  ) async {
    try {
      final result = await _authorizedGetJson(
        '/v1/attachments/download/$attachmentId',
      );
      if (result['status'] != 'success') {
        return Map<String, dynamic>.from(result);
      }

      final dynamic data = result['data'];
      final dynamic raw = result['raw'];
      final Map<dynamic, dynamic> body =
          (data is Map) ? data : (raw is Map ? raw : {});

      final String filename =
          (body['filename'] ?? body['fileName'] ?? 'attachment')
              .toString()
              .trim();
      final String mimeType =
          (body['mimeType'] ?? body['mime_type'] ?? 'application/octet-stream')
              .toString()
              .trim();
      String base64Str =
          (body['base64'] ?? body['data'] ?? '').toString().trim();

      if (base64Str.contains(';base64,')) {
        base64Str = base64Str.split(';base64,').last;
      } else if (base64Str.startsWith('data:') && base64Str.contains(','))
        base64Str = base64Str.split(',').last;
      base64Str = base64Str.replaceAll(RegExp(r'\s'), '');

      if (base64Str.isEmpty) {
        return {
          'status': 'error',
          'message': 'Download failed: server returned no file data.',
          'raw': raw,
        };
      }
      return {
        'status': 'success',
        'filename': filename,
        'mimeType': mimeType,
        'base64': base64Str,
        'raw': raw,
      };
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> uploadAttachments({
    required String ticketId,
    required List<Map<String, dynamic>> files,
    String? bearerToken,
  }) async {
    try {
      if (ticketId.isEmpty) throw Exception('Ticket ID is required');
      if (files.isEmpty) throw Exception('No files provided');

      final token = bearerToken ?? await getValidAccessToken();
      if (token == null || token.isEmpty) {
        return {
          'status': 'error',
          'message': 'No access token available. Please login again.',
        };
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/v1/upload-attachments/$ticketId'),
      );
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      for (final file in files) {
        final filePath = file['path']?.toString() ?? '';
        final fileName = file['name']?.toString() ?? 'attachment';
        if (filePath.isEmpty) continue;
        request.files.add(
          await http.MultipartFile.fromPath(
            'attachments',
            filePath,
            filename: fileName,
          ),
        );
      }

      final streamedResponse = await _client
          .send(request)
          .timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      dynamic decoded;
      try {
        decoded = json.decode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          return {
            'status': decoded['status']?.toString() ?? 'success',
            'message':
                decoded['message']?.toString() ??
                'Attachments uploaded successfully.',
            'data': decoded['data'],
            'raw': decoded,
          };
        }
        return {
          'status': 'success',
          'message': 'Attachments uploaded successfully.',
          'data': decoded,
        };
      }

      String errMsg = 'Server error: ${response.statusCode}';
      if (decoded is Map) {
        final m = decoded['message'] ?? decoded['detail'];
        if (m != null) errMsg = m.toString();
      }
      return {'status': 'error', 'message': errMsg, 'raw': decoded};
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // ─── Subscription endpoints ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> getExpiringSubscriptionsList() async =>
      _getV1WithAuth('/v1/subscriptions/list/expiring');

  static Future<Map<String, dynamic>> getSubscriptionsPaginated({
    int page = 1,
    int limit = 10,
    String search = '',
  }) async {
    final result = await _authorizedGetJson(
      '/v1/subscriptions/paginated',
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search.isNotEmpty) 'search': search,
      },
    );
    if (result['status'] != 'success') return Map<String, dynamic>.from(result);
    final wrapper = result['data'];
    List<dynamic> items = [];
    Map<String, dynamic>? pagination;
    if (wrapper is Map<String, dynamic>) {
      final inner = wrapper['data'];
      if (inner is List) items = inner;
      final pag = wrapper['pagination'];
      if (pag is Map<String, dynamic>) {
        pagination = Map<String, dynamic>.from(pag);
      }
    } else if (wrapper is List) {
      items = wrapper;
    }
    return {
      'status': 'success',
      'data': items,
      if (pagination != null) 'pagination': pagination,
      'raw': result['raw'],
    };
  }

  // FIX: getSubscriptions now correctly unwraps nested paginated response
  static Future<List<dynamic>> getSubscriptions({
    String? bearerToken,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final token = bearerToken ?? await getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('No access token available. Please login again.');
      }

      final response = await _client
          .get(
            Uri.parse(
              '$baseUrl/v1/subscriptions/paginated?page=$page&limit=$limit',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout:
                () => http.Response(
                  json.encode({
                    'status': 'error',
                    'message': 'Connection timed out. Please try again.',
                  }),
                  408,
                ),
          );

      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);

        // Some backends return HTTP 200 with { message: "Success", data: ... }
        // but omit status. Treat "data present" as success unless explicitly error.
        if (decoded is Map) {
          final statusVal = decoded['status']?.toString().toLowerCase();
          if (statusVal == 'error' || decoded['success'] == false) {
            throw Exception(
              decoded['message']?.toString() ?? 'Failed to fetch subscriptions',
            );
          }

          final inner = decoded['data'];

          // Handle: { data: { data: [...], pagination: {...} } }
          if (inner is Map && inner['data'] is List) {
            return List<dynamic>.from(inner['data'] as List);
          }

          // Handle: { data: [...] }
          if (inner is List) return List<dynamic>.from(inner);

          // Some servers nest the list under common keys
          for (final key in const ['items', 'rows', 'results', 'list']) {
            final v = decoded[key];
            if (v is List) return List<dynamic>.from(v);
            if (v is Map && v['data'] is List) {
              return List<dynamic>.from(v['data'] as List);
            }
          }

          // If we got a 200 but no list, don't throw "Success" as an error.
          return const <dynamic>[];
        }

        // Handle bare list
        if (decoded is List) return List<dynamic>.from(decoded);

        // Unknown-but-200 shape: return empty list instead of throwing "Success".
        return const <dynamic>[];
      }

      if (response.statusCode == 401) {
        // Try refresh once
        final r = await refreshToken();
        if (r['status'] == 'success' && r['accessToken'] != null) {
          return getSubscriptions(
            bearerToken: r['accessToken'].toString(),
            page: page,
            limit: limit,
          );
        }
        throw Exception('Session expired. Please login again.');
      }

      throw Exception('Server error: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching subscriptions: $e');
    }
  }

  static Future<Map<String, dynamic>> refreshStarlinkServiceLine(
    String serviceLineNumber,
  ) async {
    final result = await _authorizedGetJson(
      '/v1/starlink/refresh/$serviceLineNumber',
    );
    if (result['status'] != 'success') return Map<String, dynamic>.from(result);
    final data = result['data'];
    return {
      'status': 'success',
      'data': data is Map ? Map<String, dynamic>.from(data) : data,
      'raw': result['raw'],
    };
  }

  static Future<Map<String, dynamic>> getSubscriptionByServiceLineNumber(
    String serviceLineNumber,
  ) async {
    final result = await _authorizedGetJson(
      '/v1/subscriptions/$serviceLineNumber',
    );
    if (result['status'] != 'success') return Map<String, dynamic>.from(result);
    final data = result['data'];
    return {
      'status': 'success',
      'data': data is Map ? Map<String, dynamic>.from(data) : data,
      'raw': result['raw'],
    };
  }

  static Future<Map<String, dynamic>> getSubscriptionBillingCycleByDates(
    String serviceLineNumber, {
    required String startDate,
    required String endDate,
  }) async {
    final result = await _authorizedGetJson(
      '/v1/subscriptions/billing-cycle/$serviceLineNumber',
      queryParameters: {'startDate': startDate, 'endDate': endDate},
    );
    if (result['status'] != 'success') return Map<String, dynamic>.from(result);
    final data = result['data'];
    return {
      'status': 'success',
      'data': data is Map ? Map<String, dynamic>.from(data) : data,
      'raw': result['raw'],
    };
  }

  static Future<Map<String, dynamic>> getSubscriptionsByCustomerId(
    String customerCode,
  ) async {
    final res = await _getV1WithAuth(
      '/v1/subscriptions/customer/$customerCode',
    );
    if (res['status'] == 'success') return res;
    if (_isRoleAccessError(res)) return _getSubscriptionsForCurrentUser();
    return res;
  }

  static Future<Map<String, dynamic>> getSubscriptionsByEndUserId(
    String euCode,
  ) async {
    final res = await _getV1WithAuth('/v1/subscriptions/end-user/$euCode');
    if (res['status'] == 'success') return res;
    if (_isRoleAccessError(res)) {
      final fallback = await getSubscriptionsByCustomerCode(euCode);
      if (fallback['status'] == 'success') return fallback;
      return _getSubscriptionsForCurrentUser();
    }
    return res;
  }

  // FIX: was hitting legacy api.php (404) — now uses v1 API.
  // Some roles (e.g., end_user) may not have access to the end-user endpoint
  // but can still fetch subscriptions by customer/company code.
  static Future<Map<String, dynamic>> getSubscriptionsByEuCode(
    String euCode,
  ) async {
    final res = await _getV1WithAuth('/v1/subscriptions/end-user/$euCode');
    if (res['status'] == 'success') return res;

    if (_isRoleAccessError(res)) {
      final customerRes = await getSubscriptionsByCustomerCode(euCode);
      if (customerRes['status'] == 'success') return customerRes;
      return _getSubscriptionsForCurrentUser();
    }

    return res;
  }

  // FIX: was hitting legacy api.php (404) — now uses v1 API
  static Future<Map<String, dynamic>> getSubscriptionsByCustomerCode(
    String customerCode,
  ) async {
    final res = await _getV1WithAuth(
      '/v1/subscriptions/customer/$customerCode',
    );
    if (res['status'] == 'success') return res;
    if (_isRoleAccessError(res)) return _getSubscriptionsForCurrentUser();
    return res;
  }

  // ─── Billing endpoints ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getBillingList() async {
    final result = await _authorizedGetJson('/v1/billing/');
    if (result['status'] == 'success') {
      final raw = result['data'];
      List<dynamic> items = [];
      if (raw is List) {
        items = raw;
      } else if (raw is Map<String, dynamic> && raw['data'] is List) {
        items = raw['data'] as List;
      }
      return {'status': 'success', 'data': items, 'raw': result['raw']};
    }

    if (_isRoleAccessError(result)) {
      final profile = await _getCurrentUserContext();
      if (profile['status'] != 'success') {
        return Map<String, dynamic>.from(result);
      }

      final data = _extractUserData(profile['data']);
      final customerCode = _pickFirstNonEmpty(data, [
        'customer_code',
        'customerCode',
        'company_code',
        'companyCode',
        'com_eu_code',
        'company',
      ]);

      if (customerCode != null) {
        final customerBilling = await _authorizedGetJson(
          '/v1/billing/',
          queryParameters: {'customer_code': customerCode},
        );
        if (customerBilling['status'] == 'success') {
          final raw = customerBilling['data'];
          List<dynamic> items = [];
          if (raw is List) {
            items = raw;
          } else if (raw is Map<String, dynamic> && raw['data'] is List) {
            items = raw['data'] as List;
          }
          return {
            'status': 'success',
            'data': items,
            'raw': customerBilling['raw'],
          };
        }
      }
    }

    return Map<String, dynamic>.from(result);
  }

  static Future<Map<String, dynamic>> getBillingDetails({
    required String customerCode,
    required String cpoNumber,
    required String sidrNumber,
  }) async => _getV1WithAuth(
    '/v1/billing/details/$customerCode/$cpoNumber/$sidrNumber',
  );

  static Future<Map<String, dynamic>> getBillingCycles(
    String serviceLineNumber,
  ) async {
    try {
      final response = await _client.get(
        Uri.parse(
          '$baseUrl/api.php?action=get_billing_cycles&serviceLineNumber=$serviceLineNumber',
        ),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') return data;
        throw Exception(data['message'] ?? 'Failed to fetch billing cycles');
      }
      throw Exception('Failed to fetch billing cycles: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching billing cycles: $e');
    }
  }

  static Future<Map<String, dynamic>> makePayment({
    required String customerCode,
    required String cpoNumber,
    required String sidrNumber,
    required double amount,
  }) async {
    try {
      final accessToken = await getValidAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        return {
          'status': 'error',
          'message': 'No access token available. Please login again.',
        };
      }

      final response = await _client
          .post(
            Uri.parse('$baseUrl/v1/billing/payment'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: json.encode({
              'customer_code': customerCode,
              'cpo_number': cpoNumber,
              'sidr_number': sidrNumber,
              'amount': amount,
            }),
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout:
                () => http.Response(
                  json.encode({
                    'status': 'error',
                    'message': 'Connection timed out. Please try again.',
                  }),
                  408,
                ),
          );

      dynamic decoded;
      try {
        decoded = json.decode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          return {
            'status': decoded['status']?.toString() ?? 'success',
            'message': decoded['message']?.toString() ?? 'Payment recorded.',
            'data': decoded['data'],
            'raw': decoded,
          };
        }
        return {'status': 'success', 'message': 'Payment recorded.'};
      }

      String msg = 'Server error: ${response.statusCode}';
      if (decoded is Map) {
        final m = decoded['message'] ?? decoded['Message'];
        if (m != null) msg = m.toString();
      }
      return {'status': 'error', 'message': msg, 'raw': decoded};
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> uploadBillingRecord(
    Map<String, dynamic> payload,
  ) async {
    try {
      final accessToken = await getValidAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        return {
          'status': 'error',
          'message': 'No access token available. Please login again.',
        };
      }

      Future<http.Response> doRequest(String token) => _client
          .post(
            Uri.parse('$baseUrl/v1/billing/'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode(payload),
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout:
                () => http.Response(
                  json.encode({
                    'status': 'error',
                    'message': 'Connection timed out. Please try again.',
                  }),
                  408,
                ),
          );

      http.Response response = await doRequest(accessToken);

      if (response.statusCode == 401) {
        final r = await refreshToken();
        if (r['status'] == 'success' && r['accessToken'] != null) {
          response = await doRequest(r['accessToken'].toString());
        } else {
          await clearTokens();
          return {
            'status': 'error',
            'message': 'Session expired. Please login again.',
          };
        }
      }

      dynamic decoded;
      try {
        decoded = json.decode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          return {
            'status': decoded['status']?.toString() ?? 'success',
            'message':
                decoded['message']?.toString() ?? 'Billing record uploaded.',
            'data': decoded['data'],
            'raw': decoded,
          };
        }
        return {'status': 'success', 'message': 'Billing record uploaded.'};
      }

      String msg = 'Server error: ${response.statusCode}';
      if (decoded is Map) {
        final m = decoded['message'] ?? decoded['Message'];
        if (m != null) msg = m.toString();
      }
      return {'status': 'error', 'message': msg, 'raw': decoded};
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> logout() async {
    try {
      final accessToken = await getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        try {
          await _client
              .post(
                Uri.parse('$baseUrl/v1/auth/logout'),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'Authorization': 'Bearer $accessToken',
                },
              )
              .timeout(const Duration(seconds: 10));
        } catch (_) {}
      }
    } finally {
      await clearTokens();
    }
    return {'status': 'success', 'message': 'Logged out successfully.'};
  }

  static Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final accessToken = await getValidAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        return {
          'status': 'error',
          'message': 'No access token available. Please login again.',
        };
      }

      Future<http.Response> doRequest(String token) => _client
          .put(
            Uri.parse('$baseUrl/v1/auth/change-password'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: json.encode({
              'old_password': oldPassword,
              'new_password': newPassword,
            }),
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout:
                () => http.Response(
                  json.encode({
                    'status': 'error',
                    'message': 'Connection timed out. Please try again.',
                  }),
                  408,
                ),
          );

      http.Response response = await doRequest(accessToken);

      if (response.statusCode == 401) {
        final r = await refreshToken();
        if (r['status'] == 'success' && r['accessToken'] != null) {
          response = await doRequest(r['accessToken'].toString());
        } else {
          await clearTokens();
          return {
            'status': 'error',
            'message': 'Session expired. Please login again.',
          };
        }
      }

      dynamic decoded;
      try {
        decoded = json.decode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          return {
            'status': decoded['status']?.toString() ?? 'success',
            'message': decoded['message']?.toString() ?? 'Password changed.',
            'raw': decoded,
          };
        }
        return {'status': 'success', 'message': 'Password changed.'};
      }

      String msg = 'Server error: ${response.statusCode}';
      if (decoded is Map) {
        final m = decoded['message'] ?? decoded['Message'];
        if (m != null) msg = m.toString();
      }
      return {'status': 'error', 'message': msg, 'raw': decoded};
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  static Future<Map<String, dynamic>> sendResetPasswordEmail(
    String userId,
  ) async {
    try {
      final accessToken = await getValidAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        return {
          'status': 'error',
          'message': 'No access token available. Please login again.',
        };
      }

      Future<http.Response> doRequest(String token) => _client
          .get(
            Uri.parse('$baseUrl/v1/auth/user/send-reset-password/$userId'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout:
                () => http.Response(
                  json.encode({
                    'status': 'error',
                    'message': 'Connection timed out. Please try again.',
                  }),
                  408,
                ),
          );

      http.Response response = await doRequest(accessToken);

      if (response.statusCode == 401) {
        final r = await refreshToken();
        if (r['status'] == 'success' && r['accessToken'] != null) {
          response = await doRequest(r['accessToken'].toString());
        } else {
          await clearTokens();
          return {
            'status': 'error',
            'message': 'Session expired. Please login again.',
          };
        }
      }

      dynamic decoded;
      try {
        decoded = json.decode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) {
          return {
            'status': decoded['status']?.toString() ?? 'success',
            'message':
                decoded['message']?.toString() ?? 'Password reset email sent.',
            'data': decoded['data'],
            'raw': decoded,
          };
        }
        return {'status': 'success', 'message': 'Password reset email sent.'};
      }

      String msg = 'Server error: ${response.statusCode}';
      if (decoded is Map) {
        final m = decoded['message'] ?? decoded['Message'];
        if (m != null) msg = m.toString();
      }
      return {'status': 'error', 'message': msg, 'raw': decoded};
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}
