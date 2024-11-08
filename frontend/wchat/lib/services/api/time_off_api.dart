import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:wchat/services/storage/storage_service.dart';

class TimeOffRequestApi {
  String? baseUrl;
  final StorageService _storage = StorageService();

  TimeOffRequestApi() {
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final String response = await rootBundle.loadString('lib/data/config.json');
    final data = await json.decode(response);
    baseUrl = data['base_url'];
    print("base url: $baseUrl");
  }

  Future<String?> _getToken() async {
    return await _storage.readSecureData('token');
  }

  // Get all time off requests with optional filters
  Future<List<Map<String, dynamic>>?> getTimeOffRequests(
      {int? userId, String? status}) async {
    try {
      if (baseUrl == null) {
        await _loadUrl();
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      // Build query parameters
      final queryParams = <String, String>{};
      if (userId != null) queryParams['userId'] = userId.toString();
      if (status != null) queryParams['status'] = status;

      final uri = Uri.parse('$baseUrl/time-off')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      }

      throw Exception(
          'Failed to load time off requests: ${response.statusCode}');
    } catch (e) {
      print('Error fetching time off requests: $e');
      return null;
    }
  }

  // Get specific time off request
  Future<Map<String, dynamic>?> getTimeOffRequest(int requestId) async {
    try {
      if (baseUrl == null) {
        await _loadUrl();
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/time-off/$requestId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      } else if (response.statusCode == 404) {
        return null;
      }

      throw Exception(
          'Failed to load time off request: ${response.statusCode}');
    } catch (e) {
      print('Error fetching time off request: $e');
      return null;
    }
  }

  Future<int?> createTimeOffRequest(Map<String, dynamic> request) async {
    try {
      if (baseUrl == null) {
        await _loadUrl();
      }

      

      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/time-off'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(request),
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);
        return responseData['id'];
      }

      print('Failed to create time off request: ${response.statusCode}');
      print('Response body: ${response.body}');
      return null;
    } catch (e) {
      print('Error creating time off request: $e');
      return null;
    }
  }

  // Update time off request
  Future<bool> updateTimeOffRequest(
      int requestId, Map<String, dynamic> updates) async {
    try {
      if (baseUrl == null) {
        await _loadUrl();
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/time-off/$requestId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(updates),
      );

      if (response.statusCode == 200) {
        return true;
      }

      print('Failed to update time off request: ${response.statusCode}');
      print('Response body: ${response.body}');
      return false;
    } catch (e) {
      print('Error updating time off request: $e');
      return false;
    }
  }

  // Delete time off request
  Future<bool> deleteTimeOffRequest(int requestId) async {
    try {
      if (baseUrl == null) {
        await _loadUrl();
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/time-off/$requestId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return true;
      }

      print('Failed to delete time off request: ${response.statusCode}');
      return false;
    } catch (e) {
      print('Error deleting time off request: $e');
      return false;
    }
  }

  // Helper method to create a new time off request
  static Map<String, dynamic> createTimeOffRequestData({
    required int userId,
    required DateTime startDate,
    required DateTime endDate,
    required String requestType,
    required String reason,
    String? notes,
  }) {
    return {
      'user_id': userId,
      'start_date':
          startDate.toIso8601String().split('T')[0], // Format as YYYY-MM-DD
      'end_date': endDate.toIso8601String().split('T')[0],
      'request_type': requestType,
      'reason': reason,
      if (notes != null) 'notes': notes,
    };
  }

  // Helper method to create status update data
  static Map<String, dynamic> createStatusUpdateData({
    required String status,
    required int respondedById,
    String? notes,
  }) {
    return {
      'status': status,
      'responded_by_id': respondedById,
      if (notes != null) 'notes': notes,
    };
  }

  // Helper method to validate request type
  static bool isValidRequestType(String requestType) {
    return ['vacation', 'sick_leave', 'personal', 'other']
        .contains(requestType);
  }

  // Helper method to validate status
  static bool isValidStatus(String status) {
    return ['pending', 'approved', 'denied', 'cancelled'].contains(status);
  }
}
