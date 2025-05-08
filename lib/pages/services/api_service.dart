import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://10.0.2.2/starlink_app/backend/api.php';

  static Future<Map<String, dynamic>> getTickets() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl?action=get_tickets'));

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['status'] == 'success') {
            return data;
          } else {
            throw Exception(data['message'] ?? 'Failed to load tickets');
          }
        } catch (e) {
          print('Server response: ${response.body}');
          throw Exception(
            'Invalid server response format. Please check server logs.',
          );
        }
      } else {
        print('Server response: ${response.body}');
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Connection error: $e');
      throw Exception('Error connecting to server: $e');
    }
  }

  static Future<Map<String, dynamic>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get_categories'),
      );

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['status'] == 'success') {
            return data;
          } else {
            throw Exception(data['message'] ?? 'Failed to load categories');
          }
        } catch (e) {
          print('Server response: ${response.body}');
          throw Exception(
            'Invalid server response format. Please check server logs.',
          );
        }
      } else {
        print('Server response: ${response.body}');
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Connection error: $e');
      throw Exception('Error connecting to server: $e');
    }
  }

  static Future<Map<String, dynamic>> getAgents() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl?action=get_agents'));

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['status'] == 'success') {
            return data;
          } else {
            throw Exception(data['message'] ?? 'Failed to load agents');
          }
        } catch (e) {
          print('Server response: ${response.body}');
          throw Exception(
            'Invalid server response format. Please check server logs.',
          );
        }
      } else {
        print('Server response: ${response.body}');
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Connection error: $e');
      throw Exception('Error connecting to server: $e');
    }
  }

  static Future<Map<String, dynamic>> getSubscriptions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?action=get_subscriptions'),
      );

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['status'] == 'success') {
            return data;
          } else {
            throw Exception(data['message'] ?? 'Failed to load subscriptions');
          }
        } catch (e) {
          print('Server response: ${response.body}');
          throw Exception(
            'Invalid server response format. Please check server logs.',
          );
        }
      } else {
        print('Server response: ${response.body}');
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Connection error: $e');
      throw Exception('Error connecting to server: $e');
    }
  }

  static Future<Map<String, dynamic>> createTicket(
    Map<String, dynamic> ticketData,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?action=create_ticket'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(ticketData),
      );

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['status'] == 'success') {
            return data;
          } else {
            throw Exception(data['message'] ?? 'Failed to create ticket');
          }
        } catch (e) {
          print('Server response: ${response.body}');
          throw Exception(
            'Invalid server response format. Please check server logs.',
          );
        }
      } else {
        print('Server response: ${response.body}');
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Connection error: $e');
      throw Exception('Error connecting to server: $e');
    }
  }

  static Future<Map<String, dynamic>> updateTicket(
    String ticketId,
    Map<String, dynamic> ticketData,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl?action=update_ticket&id=$ticketId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(ticketData),
      );

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['status'] == 'success') {
            return data;
          } else {
            throw Exception(data['message'] ?? 'Failed to update ticket');
          }
        } catch (e) {
          print('Server response: ${response.body}');
          throw Exception(
            'Invalid server response format. Please check server logs.',
          );
        }
      } else {
        print('Server response: ${response.body}');
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Connection error: $e');
      throw Exception('Error connecting to server: $e');
    }
  }

  static Future<Map<String, dynamic>> deleteTicket(String ticketId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl?action=delete_ticket&id=$ticketId'),
      );

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data['status'] == 'success') {
            return data;
          } else {
            throw Exception(data['message'] ?? 'Failed to delete ticket');
          }
        } catch (e) {
          print('Server response: ${response.body}');
          throw Exception(
            'Invalid server response format. Please check server logs.',
          );
        }
      } else {
        print('Server response: ${response.body}');
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Connection error: $e');
      throw Exception('Error connecting to server: $e');
    }
  }
}
