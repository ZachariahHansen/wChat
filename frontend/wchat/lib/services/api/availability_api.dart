import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:wchat/services/storage/storage_service.dart';

class AvailabilityApi {
  String? baseUrl;
  final StorageService _storage = StorageService();

  AvailabilityApi() {
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

  // Get user availability
  Future<List<Map<String, dynamic>>?> getAvailability(int userId) async {
    try {
      if (baseUrl == null) {
        await _loadUrl();
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/availability/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['availabilities']);
      } else if (response.statusCode == 404) {
        return null;
      }

      throw Exception('Failed to load availability: ${response.statusCode}');
    } catch (e) {
      print('Error fetching availability: $e');
      return null;
    }
  }

  // Create or update availability
  Future<bool> upsertAvailability(
      int userId, List<Map<String, dynamic>> availabilities) async {
    try {
      if (baseUrl == null) {
        await _loadUrl();
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final requestBody = {'availabilities': availabilities};

      final response = await http.put(
        Uri.parse('$baseUrl/availability/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }

      print('Failed to update availability: ${response.statusCode}');
      print('Response body: ${response.body}');
      return false;
    } catch (e) {
      print('Error updating availability: $e');
      return false;
    }
  }

  // Delete availability
  Future<bool> deleteAvailability(int userId) async {
    try {
      if (baseUrl == null) {
        await _loadUrl();
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/availability/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return true;
      }

      print('Failed to delete availability: ${response.statusCode}');
      return false;
    } catch (e) {
      print('Error deleting availability: $e');
      return false;
    }
  }

  // Helper method to create a week of default availability
  static List<Map<String, dynamic>> createDefaultWeekAvailability({
    String defaultStartTime = "09:00",
    String defaultEndTime = "17:00",
    List<int> unavailableDays = const [6], // Saturday by default
  }) {
    return List.generate(7, (index) {
      return {
        "day": index,
        "start_time": defaultStartTime,
        "end_time": defaultEndTime,
        "is_available": !unavailableDays.contains(index)
      };
    });
  }

  // Helper method to validate availability times
  static bool isValidAvailabilityTime(String time) {
    try {
      final parts = time.split(':');
      if (parts.length != 2) return false;

      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);

      return hours >= 0 && hours < 24 && minutes >= 0 && minutes < 60;
    } catch (e) {
      return false;
    }
  }
}
