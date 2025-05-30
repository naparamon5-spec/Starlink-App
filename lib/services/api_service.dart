import 'dart:convert';
import 'dart:io' show Platform, HttpClient, X509Certificate;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class ApiService {
  // Get the appropriate base URL based on the platform
  static String get baseUrl {
    if (Platform.isAndroid) {
      // For Android emulator
      return 'https://api.lamco.com.ph/starlinkAPI';
    } else if (Platform.isIOS) {
      // For iOS simulator
      return 'https://api.lamco.com.ph/starlinkAPI';
    } else {
      // For physical devices, you'll need to replace this with your computer's IP address
      // For example: return 'http://192.168.1.100/starlink_app/backend';
      return 'https://api.lamco.com.ph/starlinkAPI';
    }
  }

  // Create a custom HTTP client that bypasses certificate verification
  static http.Client get _client {
    if (Platform.isAndroid || Platform.isIOS) {
      final httpClient =
          HttpClient()
            ..badCertificateCallback =
                (X509Certificate cert, String host, int port) => true;
      return IOClient(httpClient);
    }
    return http.Client();
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
                      'Connection timed out. Please check if XAMPP is running.',
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
  1. XAMPP is running (Apache and MySQL services)
  2. Database 'ardent_ticket' exists
  3. Table 'test_connection' exists in the database
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

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

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
        'attachments': processedAttachments,
      };

      print('Creating ticket with data: ${json.encode(formattedData)}');

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

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Failed to create ticket');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating ticket: $e');
      throw Exception('Failed to create ticket: $e');
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

  // Get current user info - Example method to get the logged-in user's ID
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
      return data;
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Error fetching current user: $e',
        'baseUrl': baseUrl,
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
      print('Fetching customers from: $baseUrl/api.php?action=get_customers');

      final response = await _client.get(
        Uri.parse('$baseUrl/api.php?action=get_customers'),
        headers: {'Accept': 'application/json'},
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch customers');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching customers: $e');
      throw Exception('Error fetching customers: $e');
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
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}
