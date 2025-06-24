import 'dart:convert';
import 'dart:io' show Platform, HttpClient, X509Certificate;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';
import '../config/ssl_config.dart';

class ApiService {
  // Get the appropriate base URL based on the platform
  static String get baseUrl {
    //return 'https://api.lamco.com.ph/starlinkAPI';
    return 'http://10.0.2.2/starlink_app/backend';
  }

  // Create a custom HTTP client that uses our SSL configuration
  static http.Client get _client {
    final httpClient =
        HttpClient()..connectionTimeout = const Duration(seconds: 15);

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
        'troubleshooting': '''
  Please check:
  1. Your internet connection
  2. The server is running at $baseUrl
  3. Database credentials are correct
  4. Your device/emulator can reach the server
  ''',
      };
    }
  }

  // Login user
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/login.php'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'username': username, 'password': password}),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              return http.Response(
                json.encode({
                  'status': 'error',
                  'message':
                      'Connection timed out. Please check if XAMPP is running.',
                }),
                408,
              );
            },
          );

      final data = json.decode(response.body);

      // Validate response structure
      if (data['status'] == 'success') {
        if (data['user'] == null) {
          throw Exception('Invalid response: Missing user data');
        }

        final user = data['user'] as Map<String, dynamic>;
        if (user['id'] == null) {
          throw Exception('Invalid response: Missing user ID');
        }

        // Check for either type or role
        if (user['type'] == null && user['role'] == null) {
          throw Exception('Invalid response: Missing user type/role');
        }
      }

      return data;
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
        'baseUrl': baseUrl,
      };
    }
  }

  // Get all tickets
  static Future<Map<String, dynamic>> getTickets() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api.php?action=get_tickets'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch tickets');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching tickets: $e');
    }
  }

  // Create a new ticket
  static Future<Map<String, dynamic>> createTicket(
    Map<String, dynamic> ticketData,
  ) async {
    try {
      // Validate required fields
      final requiredFields = [
        'type',
        'contact',
        'subscription',
        'description',
        'user_id',
      ];
      for (final field in requiredFields) {
        if (ticketData[field] == null || ticketData[field].toString().isEmpty) {
          throw Exception('Missing required field: $field');
        }
      }

      // Process attachments if present
      List<Map<String, dynamic>> processedAttachments = [];
      if (ticketData['attachments'] != null &&
          ticketData['attachments'] is List) {
        for (var attachment in ticketData['attachments']) {
          if (attachment is Map<String, dynamic>) {
            processedAttachments.add({
              'name': attachment['name'],
              'type': attachment['type'] ?? 'application/octet-stream',
              'size': attachment['size'],
              'data': attachment['data'],
              'file_path': attachment['file_path'] ?? '',
            });
          }
        }
      }

      // Format the data for the API
      final formattedData = {
        'type': ticketData['type'],
        'contact': ticketData['contact'],
        'contact_name': ticketData['contact_name'],
        'subscription': ticketData['subscription'],
        'description': ticketData['description'],
        'user_id': ticketData['user_id'].toString(),
        'subject': ticketData['subject'] ?? ticketData['type'],
        'attachments': processedAttachments,
      };

      final response = await _client
          .post(
            Uri.parse('$baseUrl/api.php?action=create_ticket'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(formattedData),
          )
          .timeout(
            const Duration(seconds: 30),
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

        // Ensure data is not null and has the expected structure
        if (data == null) {
          throw Exception('Invalid response: Response data is null');
        }

        if (data['status'] == 'success') {
          // Ensure data['data'] exists and is a Map
          if (data['data'] == null) {
            data['data'] = {};
          }

          // Add additional fields to the response for consistency
          data['data'] = {
            ...data['data'],
            'status': 'open',
            'created_at': DateTime.now().toIso8601String(),
            'attachments': processedAttachments,
            'user_id': ticketData['user_id'],
            'contact': ticketData['contact'],
            'contact_name': ticketData['contact_name'],
            'type': ticketData['type'],
            'subscription': ticketData['subscription'],
            'description': ticketData['description'],
            'attachments_display':
                ticketData['attachments_display'] ?? 'No attachments',
          };

          return data;
        } else {
          throw Exception(data['message'] ?? 'Failed to create ticket');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString().replaceAll('Exception: ', ''),
        'data': null,
      };
    }
  }

  // Get ticket categories
  static Future<Map<String, dynamic>> getCategories() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api.php?action=get_categories'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch categories');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching categories: $e');
    }
  }

  // Get agents
  static Future<Map<String, dynamic>> getAgents() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api.php?action=get_agents'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          // Ensure agent IDs are integers
          if (data['data'] != null && data['data'] is List) {
            data['data'] =
                (data['data'] as List).map((agent) {
                  if (agent is Map<String, dynamic>) {
                    return {
                      ...agent,
                      'id': int.tryParse(agent['id'].toString()) ?? agent['id'],
                    };
                  }
                  return agent;
                }).toList();
          }
          return data;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch agents');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching agents: $e');
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

  // Get all subscriptions (deprecated, use getSubscriptionsByEuCode instead)
  static Future<Map<String, dynamic>> getSubscriptions() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api.php?action=get_subscriptions'),
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

        // Validate response structure
        if (data['status'] == 'success' && data['data'] != null) {
          // Ensure customer IDs are integers
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

  // Forgot password with improved error handling
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api.php?action=forgot_password'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({'email': email}),
          )
          .timeout(
            const Duration(seconds: 15),
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
          throw Exception(
            data['message'] ?? 'Failed to process password reset request',
          );
        }
      } else if (response.statusCode == 500) {
        throw Exception('Server error occurred. Please try again later.');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('CERTIFICATE_VERIFY_FAILED')) {
        if (SSLConfig.isDevelopment) {
          return {
            'status': 'error',
            'message':
                'SSL Certificate verification failed in development mode. Please check your certificate configuration.',
            'details': e.toString(),
          };
        } else {
          return {
            'status': 'error',
            'message':
                'SSL Certificate verification failed. Please contact support.',
            'details': e.toString(),
          };
        }
      }
      return {
        'status': 'error',
        'message':
            'Failed to process password reset request. Please try again.',
        'details': e.toString(),
      };
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
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}
