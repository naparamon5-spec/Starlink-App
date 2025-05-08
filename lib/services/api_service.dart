import 'dart:convert';
import 'dart:io' show Platform;
import 'package:http/http.dart' as http;

class ApiService {
  // Get the appropriate base URL based on the platform
  static String get baseUrl {
    if (Platform.isAndroid) {
      // For Android emulator
      return 'http://10.0.2.2/starlink_app/backend';
    } else if (Platform.isIOS) {
      // For iOS simulator
      return 'http://localhost/starlink_app/backend';
    } else {
      // For physical devices, you'll need to replace this with your computer's IP address
      // For example: return 'http://192.168.1.100/starlink_app/backend';
      return 'http://localhost/starlink_app/backend';
    }
  }

  // Test database connection
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      print('Attempting to connect to: $baseUrl/test_connection.php');

      final response = await http
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

      final response = await http
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
      print('Fetching tickets from: $baseUrl/api.php?action=get_tickets');

      final response = await http
          .get(Uri.parse('$baseUrl/api.php?action=get_tickets'))
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
        'message': 'Error connecting to server: $e',
        'baseUrl': baseUrl,
        'troubleshooting': '''
Please check:
1. XAMPP is running (Apache and MySQL services)
2. Your device/emulator can reach the server
3. The correct IP address is being used:
   - Android Emulator: 10.0.2.2
   - iOS Simulator: localhost
   - Physical Device: Your computer's IP address
4. The backend files are in the correct location: /starlink_app/backend/
''',
      };
    }
  }

  // Create a new ticket
  static Future<Map<String, dynamic>> createTicket({
    required String type,
    required String contact,
    required String subscription,
    required String description,
  }) async {
    try {
      print('Creating ticket at: $baseUrl/api.php?action=create_ticket');

      final response = await http
          .post(
            Uri.parse('$baseUrl/api.php?action=create_ticket'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'type': type,
              'contact': contact,
              'subscription': subscription,
              'description': description,
            }),
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
        'message': 'Error creating ticket: $e',
        'baseUrl': baseUrl,
      };
    }
  }

  // Get ticket categories
  static Future<Map<String, dynamic>> getCategories() async {
    try {
      print('Fetching categories from: $baseUrl/api.php?action=get_categories');

      final response = await http
          .get(Uri.parse('$baseUrl/api.php?action=get_categories'))
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
        'message': 'Error fetching categories: $e',
        'baseUrl': baseUrl,
      };
    }
  }

  // Get agents
  static Future<Map<String, dynamic>> getAgents() async {
    try {
      print('Fetching agents from: $baseUrl/api.php?action=get_agents');

      final response = await http
          .get(Uri.parse('$baseUrl/api.php?action=get_agents'))
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
        'message': 'Error fetching agents: $e',
        'baseUrl': baseUrl,
      };
    }
  }

  // Get subscriptions
  static Future<Map<String, dynamic>> getSubscriptions() async {
    try {
      print(
        'Fetching subscriptions from: $baseUrl/api.php?action=get_subscriptions',
      );

      final response = await http
          .get(Uri.parse('$baseUrl/api.php?action=get_subscriptions'))
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
        'message': 'Error fetching subscriptions: $e',
        'baseUrl': baseUrl,
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
