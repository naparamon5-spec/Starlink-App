import 'dart:convert';
// dart:io is not available on web; only import what's needed conditionally
import 'dart:io' show HttpClient, X509Certificate;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/ssl_config.dart';

class ApiService {
  // Get the appropriate base URL based on the platform
  static String get baseUrl {
    return 'https://starlink-api.ardentnetworks.com.ph/api';
  }

  // Create a custom HTTP client that uses our SSL configuration.
  static http.Client get _client {
    if (kIsWeb) {
      return http.Client();
    }

    final httpClient =
        HttpClient()
          ..connectionTimeout = const Duration(seconds: 15)
          ..badCertificateCallback = (cert, host, port) => true; // dev only

    return IOClient(httpClient);
  }

  // Test database connection
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/test_connection.php'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              return http.Response(
                json.encode({
                  'status': 'error',
                  'message':
                      'Connection timed out. Please check your internet connection.',
                }),
                408,
              );
            },
          );

      final data = json.decode(response.body);
      return data;
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Connection error: $e',
        'baseUrl': baseUrl,
      };
    }
  }

  // Login user
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
        final inner = Map<String, dynamic>.from(data['data']);
        data.addAll(inner);
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

      if (data.containsKey('userId') && data['flag'] == false) {
        return data;
      }

      throw Exception('Unexpected response format: ${response.body}');
    } catch (e) {
      return {'status': 'error', 'message': e.toString(), 'baseUrl': baseUrl};
    }
  }

  // Verify OTP after login for end users
  static Future<dynamic> verifyOtp(String email, String otp) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/auth/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to verify OTP');
    }
  }

  // ─── Token Management ────────────────────────────────────────────────────────

  // Get access token from SharedPreferences
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  // Get refresh token from SharedPreferences
  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refreshToken');
  }

  // Store access token
  static Future<void> setAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', token);
  }

  // Store refresh token
  static Future<void> setRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('refreshToken', token);
  }

  // Clear all tokens
  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
  }

  // Refresh access token using refresh token
  static Future<Map<String, dynamic>> refreshToken() async {
    try {
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
        if (data['accessToken'] != null) {
          // Store the new access token
          await setAccessToken(data['accessToken']);
          return {
            'status': 'success',
            'accessToken': data['accessToken'],
          };
        } else {
          throw Exception('No access token in refresh response');
        }
      } else {
        // If refresh fails, clear tokens
        await clearTokens();
        throw Exception('Token refresh failed: ${response.statusCode}');
      }
    } catch (e) {
      await clearTokens();
      return {
        'status': 'error',
        'message': e.toString(),
      };
    }
  }

  // Get a valid access token, refreshing if necessary
  static Future<String?> getValidAccessToken() async {
    String? accessToken = await getAccessToken();
    
    // If we have an access token, try to use it
    // In a real implementation, you might want to check token expiration
    // For now, we'll just return it if it exists
    if (accessToken != null && accessToken.isNotEmpty) {
      return accessToken;
    }

    // If no access token, try to refresh
    final refreshResult = await refreshToken();
    if (refreshResult['status'] == 'success') {
      return refreshResult['accessToken'];
    }

    return null;
  }

  static Future<Map<String, dynamic>> _authorizedGetJson(
    String path, {
    Map<String, String>? queryParameters,
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

      Future<http.Response> doRequest(String token) {
        return _client
            .get(
              uri,
              headers: {
                'Accept': 'application/json',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'Connection timed out. Please check your internet connection.',
                );
              },
            );
      }

      http.Response response = await doRequest(accessToken);

      if (response.statusCode == 401) {
        final refreshResult = await refreshToken();
        if (refreshResult['status'] == 'success') {
          final newAccessToken = refreshResult['accessToken']?.toString();
          if (newAccessToken != null && newAccessToken.isNotEmpty) {
            response = await doRequest(newAccessToken);
          }
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
          return {'status': 'success', 'data': data, 'raw': decoded};
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
          'raw': decoded,
        };
      }

      return {
        'status': 'error',
        'message': 'Server error: ${response.statusCode}',
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

  static Future<Map<String, dynamic>> _getV1WithAuth(
    String path, {
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

      Future<http.Response> doRequest(String token) {
        return _client
            .get(
              Uri.parse('$baseUrl$path'),
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
      }

      http.Response response = await doRequest(accessToken);

      if (response.statusCode == 401) {
        final refreshResult = await refreshToken();
        if (refreshResult['status'] == 'success' &&
            refreshResult['accessToken'] != null) {
          response = await doRequest(refreshResult['accessToken'].toString());
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
        return {
          'status': 'success',
          'data': decoded,
          'message': 'Success',
          'raw': decoded,
        };
      }

      if (response.statusCode == 401) {
        await clearTokens();
        return {
          'status': 'error',
          'message': 'Session expired. Please login again.',
          'statusCode': response.statusCode,
          'raw': decoded,
        };
      }

      String serverMessage = 'Server error: ${response.statusCode}';
      if (decoded is Map) {
        final msg = decoded['message'] ?? decoded['Message'];
        if (msg != null) serverMessage = msg.toString();
      }
      return {
        'status': 'error',
        'message': serverMessage,
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

  // /api/v1/auth/me GET
  static Future<Map<String, dynamic>> getMe() async {
    return _getV1WithAuth('/v1/auth/me');
  }

  // /api/v1/tickets/mine/open GET
  static Future<Map<String, dynamic>> getMyOpenTickets() async {
    return _getV1WithAuth('/v1/tickets/mine/open');
  }

  // /api/v1/tickets/mine/in-progress GET
  static Future<Map<String, dynamic>> getMyInProgressTickets() async {
    return _getV1WithAuth('/v1/tickets/mine/in-progress');
  }

  // /api/v1/tickets/mine/resolved GET
  static Future<Map<String, dynamic>> getMyResolvedTickets() async {
    return _getV1WithAuth('/v1/tickets/mine/resolved');
  }

  // /api/v1/tickets/mine/closed GET
  static Future<Map<String, dynamic>> getMyClosedTickets() async {
    return _getV1WithAuth('/v1/tickets/mine/closed');
  }

  // /api/v1/tickets/recent/activity GET
  static Future<Map<String, dynamic>> getRecentTicketActivity() async {
    return _getV1WithAuth('/v1/tickets/recent/activity');
  }

  // /api/v1/subscriptions/list/expiring GET
  static Future<Map<String, dynamic>> getExpiringSubscriptionsList() async {
    return _getV1WithAuth('/v1/subscriptions/list/expiring');
  }

  // Get current user profile using /api/v1/auth/me
  static Future<Map<String, dynamic>> getCurrentUserProfile() async {
    try {
      print('[DEBUG] getCurrentUserProfile: Starting to get user profile');
      // Get valid access token (will refresh if needed)
      final accessToken = await getValidAccessToken();
      
      if (accessToken == null || accessToken.isEmpty) {
        print('[DEBUG] getCurrentUserProfile: No access token available');
        return {
          'status': 'error',
          'message': 'No access token available. Please login again.',
        };
      }

      print('[DEBUG] getCurrentUserProfile: Calling /api/v1/auth/me');
      final response = await _client
          .get(
            Uri.parse('$baseUrl/v1/auth/me'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Connection timed out. Please check your internet connection.',
              );
            },
          );

      print('[DEBUG] getCurrentUserProfile: Response status: ${response.statusCode}');
      print('[DEBUG] getCurrentUserProfile: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle different response formats
        if (data is Map<String, dynamic>) {
          if (data.containsKey('data')) {
            print('[DEBUG] getCurrentUserProfile: Success - data found in response.data');
            return {
              'status': 'success',
              'data': data['data'],
            };
          } else {
            print('[DEBUG] getCurrentUserProfile: Success - data is root level');
            return {
              'status': 'success',
              'data': data,
            };
          }
        } else {
          throw Exception('Invalid response format');
        }
      } else if (response.statusCode == 401) {
        print('[DEBUG] getCurrentUserProfile: Token expired, attempting refresh');
        // Token expired, try to refresh
        final refreshResult = await refreshToken();
        if (refreshResult['status'] == 'success') {
          print('[DEBUG] getCurrentUserProfile: Token refreshed, retrying request');
          // Retry the request with new token
          final newAccessToken = refreshResult['accessToken'];
          final retryResponse = await _client.get(
            Uri.parse('$baseUrl/v1/auth/me'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $newAccessToken',
            },
          );

          if (retryResponse.statusCode == 200) {
            final retryData = json.decode(retryResponse.body);
            if (retryData is Map<String, dynamic>) {
              if (retryData.containsKey('data')) {
                return {
                  'status': 'success',
                  'data': retryData['data'],
                };
              } else {
                return {
                  'status': 'success',
                  'data': retryData,
                };
              }
            }
          }
        }
        // If refresh failed, clear tokens
        await clearTokens();
        print('[DEBUG] getCurrentUserProfile: Token refresh failed');
        return {
          'status': 'error',
          'message': 'Session expired. Please login again.',
        };
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('[DEBUG] getCurrentUserProfile: Error - ${e.toString()}');
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // Get user by ID using /api/v1/users/:id (pass "undefined" to get self)
  static Future<Map<String, dynamic>> getUserById(String userId) async {
    try {
      print('[DEBUG] getUserById: Starting to get user by ID: $userId');
      // Get valid access token (will refresh if needed)
      final accessToken = await getValidAccessToken();
      
      if (accessToken == null || accessToken.isEmpty) {
        print('[DEBUG] getUserById: No access token available');
        return {
          'status': 'error',
          'message': 'No access token available. Please login again.',
        };
      }

      // Use "undefined" if userId is empty or null to get self
      final userIdParam = (userId.isEmpty || userId == 'null' || userId == 'undefined') 
          ? 'undefined' 
          : userId;
      
      print('[DEBUG] getUserById: Calling /api/v1/users/$userIdParam');
      final response = await _client
          .get(
            Uri.parse('$baseUrl/v1/users/$userIdParam'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Connection timed out. Please check your internet connection.',
              );
            },
          );

      print('[DEBUG] getUserById: Response status: ${response.statusCode}');
      print('[DEBUG] getUserById: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle different response formats
        if (data is Map<String, dynamic>) {
          if (data.containsKey('data')) {
            print('[DEBUG] getUserById: Success - data found in response.data');
            return {
              'status': 'success',
              'data': data['data'],
            };
          } else {
            print('[DEBUG] getUserById: Success - data is root level');
            return {
              'status': 'success',
              'data': data,
            };
          }
        } else {
          throw Exception('Invalid response format');
        }
      } else if (response.statusCode == 401) {
        print('[DEBUG] getUserById: Token expired, attempting refresh');
        // Token expired, try to refresh
        final refreshResult = await refreshToken();
        if (refreshResult['status'] == 'success') {
          print('[DEBUG] getUserById: Token refreshed, retrying request');
          // Retry the request with new token
          final newAccessToken = refreshResult['accessToken'];
          final retryResponse = await _client.get(
            Uri.parse('$baseUrl/v1/users/$userIdParam'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $newAccessToken',
            },
          );

          if (retryResponse.statusCode == 200) {
            final retryData = json.decode(retryResponse.body);
            if (retryData is Map<String, dynamic>) {
              if (retryData.containsKey('data')) {
                return {
                  'status': 'success',
                  'data': retryData['data'],
                };
              } else {
                return {
                  'status': 'success',
                  'data': retryData,
                };
              }
            }
          }
        }
        // If refresh failed, clear tokens
        await clearTokens();
        print('[DEBUG] getUserById: Token refresh failed');
        return {
          'status': 'error',
          'message': 'Session expired. Please login again.',
        };
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('[DEBUG] getUserById: Error - ${e.toString()}');
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // Resend OTP
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
        if (data['status'] == 'success') {
          return data;
        } else {
          return {
            'status': 'error',
            'message': data['message'] ?? 'Failed to resend OTP',
          };
        }
      } else {
        return {
          'status': 'error',
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Failed to resend OTP: $e'};
    }
  }

  // Get tickets
  static Future<Map<String, dynamic>> getTickets({
    int page = 1,
    int limit = 10,
    String? status,
    String? ticketType,
    String? createdBy,
    String? requestedBy,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (status != null) 'status': status,
        if (ticketType != null) 'ticket_type': ticketType,
        if (createdBy != null) 'created_by': createdBy,
        if (requestedBy != null) 'requested_by': requestedBy,
        if (search != null) 'search': search,
      };

      final uri = Uri.parse(
        '$baseUrl/v1/tickets/',
      ).replace(queryParameters: queryParams);

      final response = await _client.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid response format');
      }

      if (data['status'] == 'success' && data['data'] != null) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch tickets');
      }
    } catch (e) {
      throw Exception('Error fetching tickets: $e');
    }
  }

  // ─── createTicket ─────────────────────────────────────────────────────────
  //
  // Positional-Map overload — called by customer_ticket_modal.dart as:
  //   final response = await ApiService.createTicket(newTicket);
  //
  // ─────────────────────────────────────────────────────────────────────────
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

  // Named-parameter version — use for new code or when you have individual values.
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

      List<Map<String, dynamic>> processedAttachments = [];
      if (attachments != null) {
        for (var attachment in attachments) {
          processedAttachments.add({
            'name': attachment['name'],
            'type': attachment['type'] ?? 'application/octet-stream',
            'size': attachment['size'],
            'data': attachment['data'],
          });
        }
      }

      final requestBody = {
        'description': description,
        'ticket_type': ticketType,
        'subscription_id': subscriptionId,
        'contact': contact,
        'subject': '$nickname - $ticketType',
        'attachments': processedAttachments,
      };

      final response = await _client
          .post(
            Uri.parse('$baseUrl/v1/tickets/'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
            },
            body: json.encode(requestBody),
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
      } else {
        throw Exception(data['message'] ?? 'Failed to create ticket');
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
        'data': null,
      };
    }
  }

  // ─── getCategories ────────────────────────────────────────────────────────
  //
  // Returns Map<String, dynamic> with 'status' + 'data' keys so callers can:
  //   if (result['status'] == 'success' && result['data'] != null) { ... }
  //
  // ─────────────────────────────────────────────────────────────────────────
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
        // Backend normally returns { status, data: [...] } — pass through
        if (data is Map<String, dynamic>) {
          return data;
        }
        // Fallback: bare list returned — wrap it
        if (data is List) {
          return {'status': 'success', 'data': data};
        }
        return {'status': 'error', 'message': 'Unexpected response format'};
      } else {
        return {
          'status': 'error',
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Error fetching categories: $e'};
    }
  }

  // Get contacts
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
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch contacts');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching contacts: $e');
    }
  }

  // Get available ticket filter options
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
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return {
            'statuses': data['data']['statuses'] ?? [],
            'ticket_types': data['data']['ticket_types'] ?? [],
            'created_by': data['data']['created_by'] ?? [],
            'assigned_by': data['data']['assigned_by'] ?? [],
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch ticket filters');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching ticket filters: $e');
    }
  }

  // Get subscriptions by EU code
  static Future<Map<String, dynamic>> getSubscriptionsByEuCode(
    String euCode,
  ) async {
    try {
      final response = await _client.get(
        Uri.parse(
          '$baseUrl/api.php?action=get_subscriptions_by_eu_code&eu_code=$euCode',
        ),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch subscriptions');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching subscriptions: $e');
    }
  }

  static Future<Map<String, dynamic>> getSubscriptionsByCustomerCode(
    String customerCode,
  ) async {
    try {
      final response = await _client.get(
        Uri.parse(
          '$baseUrl/api.php?action=get_subscriptions_by_customer_code&customer_code=$customerCode',
        ),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch subscriptions');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching subscriptions: $e');
    }
  }

  // getSubscriptions — fixed URL (baseUrl already ends with '/api')
  static Future<List<dynamic>> getSubscriptions({
    String? bearerToken,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse(
              '$baseUrl/v1/subscriptions/paginated?page=$page&limit=$limit',
            ),
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
                    'message': 'Connection timed out. Please try again.',
                  }),
                  408,
                ),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data is Map &&
            data['status'] == 'success' &&
            data['data'] is List) {
          return List<dynamic>.from(data['data']);
        }

        if (data is List) {
          return List<dynamic>.from(data);
        }

        throw Exception(data['message'] ?? 'Failed to fetch subscriptions');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching subscriptions: $e');
    }
  }

  // Get current user info
  static Future<Map<String, dynamic>> getCurrentUser(int userId) async {
    try {
      final response = await _client
          .get(
            Uri.parse(
              '$baseUrl/api.php?action=get_current_user&user_id=$userId',
            ),
            headers: {'Accept': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'Connection timed out. Please check your internet connection.',
              );
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch user data');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // Update ticket status
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
        if (data['status'] == 'success') {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Failed to update ticket status');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
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

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load ticket categories');
      }
    } catch (e) {
      throw Exception('Error: $e');
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
            onTimeout: () {
              return http.Response(
                json.encode({
                  'status': 'error',
                  'message': 'Connection timed out. Please try again.',
                }),
                408,
              );
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' || data['success'] == true) {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Failed to update password');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  // Get all customers
  static Future<Map<String, dynamic>> getCustomers() async {
    try {
      final response = await _client
          .get(
            Uri.parse('$baseUrl/api.php?action=get_agents'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'Connection timed out. Please check your internet connection.',
              );
            },
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success' && data['data'] != null) {
          if (data['data'] is List) {
            data['data'] =
                (data['data'] as List).map((customer) {
                  if (customer is Map<String, dynamic>) {
                    return {
                      ...customer,
                      'id':
                          int.tryParse(customer['id'].toString()) ??
                          customer['id'],
                    };
                  }
                  return customer;
                }).toList();
          }
          return data;
        } else {
          throw Exception(
            data['message'] ?? 'Invalid response format from server',
          );
        }
      } else {
        throw Exception(
          'Server error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception(
          'Connection timed out. Please check your internet connection.',
        );
      }
      throw Exception('Error fetching customers: ${e.toString()}');
    }
  }

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
        if (data['status'] == 'success') {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch billing cycles');
        }
      } else {
        throw Exception(
          'Failed to fetch billing cycles: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching billing cycles: $e');
    }
  }

  // Forgot password
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

  // Get end user by user ID
  static Future<Map<String, dynamic>> getEndUserByUserId(int userId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api.php?action=get_end_user&user_id=$userId'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch end user data');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching end user data: $e');
    }
  }

  // Get contacts by EU code
  static Future<Map<String, dynamic>> getContactsByEuCode(String euCode) async {
    try {
      final response = await _client.get(
        Uri.parse(
          '$baseUrl/api.php?action=get_contacts_by_eu_code&eu_code=$euCode',
        ),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch contacts');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching contacts: $e');
    }
  }

  // Update user profile
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
      if (response.statusCode == 200) {
        final respData = json.decode(response.body);
        return respData;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}
