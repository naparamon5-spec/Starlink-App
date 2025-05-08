import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;

class ApiService {
  // Get the appropriate base URL based on the platform
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2/starlink_app/backend';
    } else if (Platform.isIOS) {
      return 'http://localhost/starlink_app/backend';
    } else {
      // For physical devices, you'll need to replace this with your computer's IP address
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
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}
