import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:wchat/services/storage/storage_service.dart';

class AISchedulingService {
  String? baseUrl;
  final StorageService _storage = StorageService();

  AISchedulingService() {
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

  Future<Map<String, dynamic>> generateSchedule({
    required String requirements,
    required int departmentId,
    required String date,
  }) async {
    try {
      if (baseUrl == null) {
        await _loadUrl();
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/ai/schedule'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode({
          'requirements': requirements,
          'department_id': departmentId,
          'date': date,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Failed to generate schedule: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to generate schedule: ${response.body}');
      }
    } catch (e) {
      print('Error generating schedule: $e');
      throw Exception('Error generating schedule: $e');
    }
  }
}