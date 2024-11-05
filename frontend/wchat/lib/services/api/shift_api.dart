import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:wchat/services/storage/storage_service.dart';
import 'package:wchat/data/models/shift.dart';
import 'package:wchat/services/storage/jwt_decoder.dart';

class ShiftApi {
  String? baseUrl;
  final StorageService _storage = StorageService();

  ShiftApi() {
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

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<dynamic>> getShifts() async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/shifts'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load shifts');
    }
  }

  Future<Map<String, dynamic>> getShift(int shiftId) async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/shifts/$shiftId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load shift');
    }
  }

  Future<Map<String, dynamic>> createShift(
      Map<String, dynamic> shiftData) async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/shifts'),
      headers: headers,
      body: jsonEncode(shiftData),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create shift');
    }
  }

  Future<Map<String, dynamic>> updateShift(
      int shiftId, Map<String, dynamic> shiftData) async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.put(
      Uri.parse('$baseUrl/shifts/$shiftId'),
      headers: headers,
      body: jsonEncode(shiftData),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update shift');
    }
  }

  Future<void> deleteShift(int shiftId) async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.delete(
      Uri.parse('$baseUrl/shifts/$shiftId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete shift');
    }
  }

  Future<Shift> getNextShift() async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    try {
      final tokenData = await JwtDecoder.decode();
      final userId = tokenData['user_id'];

      if (userId == null) {
        throw Exception('User ID not found in JWT token');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/shifts/next/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Shift.fromJson(data);
      } else {
        throw Exception('Failed to load next shift');
      }
    } catch (e) {
      throw Exception('Error getting next shift: $e');
    }
  }

  Future<List<Shift>> getUserAvailableShifts() async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    try {
      final tokenData = await JwtDecoder.decode();
      final userId = tokenData['user_id'];

      if (userId == null) {
        throw Exception('User ID not found in JWT token');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/shifts/user/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> shiftsJson = json.decode(response.body);
        return shiftsJson.map((json) => Shift.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load user available shifts');
      }
    } catch (e) {
      throw Exception('Error getting user available shifts: $e');
    }
  }

  Future<Map<String, dynamic>> getAvailableShifts() async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/shift-exchange'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load available shifts');
    }
  }

  Future<void> pickupShift(int shiftId) async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/shift-exchange/pickup'),
      headers: headers,
      body: jsonEncode({
        'shift_id': shiftId,
      }),
    );

    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      final errorMessage = errorData['error'] ?? 'Failed to pick up shift';
      throw Exception(errorMessage);
    }
  }

  Future<void> relinquishShift(int shiftId) async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/shift-exchange/relinquish'),
      headers: headers,
      body: jsonEncode({
        'shift_id': shiftId,
      }),
    );

    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      final errorMessage = errorData['error'] ?? 'Failed to relinquish shift';
      throw Exception(errorMessage);
    }
  }

  Future<bool> assignShift(int shiftId, int userId) async {
    try {
      if (baseUrl == null) await _loadUrl();

      final headers = await _getHeaders();

      final url = Uri.parse('$baseUrl/shifts/assign');

      final body = jsonEncode({
        'shift_id': shiftId,
        'user_id': userId,
      });

      final response = await http.put(
        url,
        headers: headers,
        body: body,
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print('Successfully assigned shift: ${responseData['message']}');
        return true;
      } else {
        final errorMessage = responseData['error'] ?? 'Failed to assign shift';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error assigning shift: $e');
      throw Exception('Failed to assign shift: $e');
    }
  }

  Future<ShiftResponse> getAllShifts({
    int? departmentId,
    int? userId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      if (baseUrl == null) await _loadUrl();

      // Get the authentication token
      final headers = await _getHeaders();

      // Build query parameters
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      // Add optional filters if provided
      if (departmentId != null) {
        queryParams['department_id'] = departmentId.toString();
      }
      if (userId != null) {
        queryParams['user_id'] = userId.toString();
      }
      if (status != null) {
        queryParams['status'] = status;
      }
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String();
      }

      // Build the URL with query parameters
      final uri = Uri.parse('$baseUrl/shifts/all')
          .replace(queryParameters: queryParams);

      // Make the GET request
      final response = await http.get(
        uri,
        headers: headers,
      );

      // Parse the response
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Parse shifts array
        final List<dynamic> shiftsJson = responseData['shifts'];
        final List<Shift> shifts =
            shiftsJson.map((json) => Shift.fromJson(json)).toList();

        // Parse pagination data
        final pagination = PaginationInfo(
          total: responseData['pagination']['total'],
          limit: responseData['pagination']['limit'],
          offset: responseData['pagination']['offset'],
        );

        return ShiftResponse(shifts: shifts, pagination: pagination);
      } else {
        final errorMessage =
            jsonDecode(response.body)['error'] ?? 'Failed to fetch shifts';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error fetching shifts: $e');
      throw Exception('Failed to fetch shifts: $e');
    }
  }

  Future<bool> unassignShift(int shiftId) async {
    try {
      if (baseUrl == null) await _loadUrl();

      final headers = await _getHeaders();

      final url = Uri.parse('$baseUrl/shifts/unassign');

      final body = jsonEncode({
        'shift_id': shiftId,
      });

      final response = await http.put(
        url,
        headers: headers,
        body: body,
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print('Successfully unassigned shift: ${responseData['message']}');
        return true;
      } else {
        final errorMessage =
            responseData['error'] ?? 'Failed to unassign shift';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error unassigning shift: $e');
      throw Exception('Failed to unassign shift: $e');
    }
  }
}

/// Response class containing shifts and pagination information
class ShiftResponse {
  final List<Shift> shifts;
  final PaginationInfo pagination;

  ShiftResponse({
    required this.shifts,
    required this.pagination,
  });
}

/// Pagination information class
class PaginationInfo {
  final int total;
  final int limit;
  final int offset;

  PaginationInfo({
    required this.total,
    required this.limit,
    required this.offset,
  });

  /// Calculate the total number of pages
  int get totalPages => (total / limit).ceil();

  /// Calculate the current page number (1-based)
  int get currentPage => (offset / limit).floor() + 1;

  /// Check if there is a next page
  bool get hasNextPage => offset + limit < total;

  /// Check if there is a previous page
  bool get hasPreviousPage => offset > 0;
}
