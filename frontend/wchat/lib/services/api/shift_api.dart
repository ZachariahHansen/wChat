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

  Future<Map<String, dynamic>> createShift(Map<String, dynamic> shiftData) async {
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

  Future<Map<String, dynamic>> updateShift(int shiftId, Map<String, dynamic> shiftData) async {
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

  
}
