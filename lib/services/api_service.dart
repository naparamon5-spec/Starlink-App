import 'dart:convert';
import 'dart:io' show Platform, HttpClient, X509Certificate;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';
import '../config/ssl_config.dart';

class ApiService {
  // Get the appropriate base URL based on the platform
  static String get baseUrl {
    return 'https://api.lamco.com.ph/starlinkAPI';
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
      print('Attempting to connect to: $baseUrl/test_connection.php');

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

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

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
      print('Attempting to login: $baseUrl/login.php');

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

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

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
      print('Login error: $e');
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
      print('Fetching tickets from: $baseUrl/api.php?action=get_tickets');

      final response = await _client.get(
        Uri.parse('$baseUrl/api.php?action=get_tickets'),
        headers: {'Accept': 'application/json'},
      );

      print('Get tickets response status: ${response.statusCode}');
      print('Get tickets response body: ${response.body}');

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
      print('Error fetching tickets: $e');
      throw Exception('Error fetching tickets: $e');
    }
  }

  // Create a new ticket
  static Future<Map<String, dynamic>> createTicket(
    Map<String, dynamic> ticketData,
  ) async {
    try {
      print('Creating ticket with data: $ticketData');

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
              'file_name': attachment['name'],
              'original_name': attachment['name'],
              'file_type': attachment['type'] ?? 'application/octet-stream',
              'file_size': attachment['size'],
              'file_data': attachment['data'],
              'uploaded_by': ticketData['user_id'],
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
        'assigned_agent': ticketData['contact'],
        'status': 'open',
        'subject': ticketData['subject'] ?? ticketData['type'],
        'attachments': processedAttachments,
        'created_at': DateTime.now().toIso8601String(),
      };

      print('Sending formatted ticket data: $formattedData');

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

      print('Create ticket response status: ${response.statusCode}');
      print('Create ticket response body: ${response.body}');

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
            'status': 'OPEN',
            'created_at': formattedData['created_at'],
            'attachments': processedAttachments,
            'contact_name': ticketData['contact_name'],
          };
          return data;
        } else {
          throw Exception(data['message'] ?? 'Failed to create ticket');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating ticket: $e');
      // Return a properly formatted error response
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
      print('Fetching agents from: $baseUrl/api.php?action=get_agents');

      final response = await _client.get(
        Uri.parse('$baseUrl/api.php?action=get_agents'),
        headers: {'Accept': 'application/json'},
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

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
      print('Error fetching agents: $e');
      throw Exception('Error fetching agents: $e');
    }
  }

  // Get subscriptions
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
      print(
        'Fetching current user from: $baseUrl/api.php?action=get_current_user&user_id=$userId',
      );

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

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

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
      print('Error in getCurrentUser: $e');
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
      print(
        'Updating ticket status: $baseUrl/api.php?action=update_ticket_status',
      );

      final response = await _client.post(
        Uri.parse('$baseUrl/api.php?action=update_ticket_status'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'ticket_id': ticketId, 'status': newStatus}),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

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
      print('Error updating ticket status: $e');
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
      print('Updating password for user: $userId');

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

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

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
      print('Error updating password: $e');
      throw Exception('Failed to update password: $e');
    }
  }

  // Get all customers
  static Future<Map<String, dynamic>> getCustomers() async {
    try {
      print('Fetching customers from: $baseUrl/api.php?action=get_agents');

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

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

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
      print('Error fetching customers: $e');
      if (e is TimeoutException) {
        throw Exception(
          'Connection timed out. Please check your internet connection.',
        );
      }
      throw Exception('Error fetching customers: ${e.toString()}');
    }
  }

  static Future<Map<String, dynamic>> getBillingCycles(
    String subscriptionId,
  ) async {
    try {
      final response = await _client.get(
        Uri.parse(
          '$baseUrl/api.php?action=get_billing_cycles&subscription_id=$subscriptionId',
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
      print('Attempting password reset for email: $email');
      print('Sending request to: $baseUrl/api.php?action=forgot_password');

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

      print('Password reset response status: ${response.statusCode}');
      print('Password reset response body: ${response.body}');

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
        print('Server error details: ${response.body}');
        throw Exception('Server error occurred. Please try again later.');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during password reset: $e');
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
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}
