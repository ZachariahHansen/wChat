import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:wchat/services/storage/storage_service.dart';

class ForgotPasswordApi {
  String? baseUrl;
  final StorageService _storage = StorageService();

  ForgotPasswordApi() {
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final String response = await rootBundle.loadString('lib/data/config.json');
    final data = await json.decode(response);
    baseUrl = data['base_url'];
    print("base url: $baseUrl");
  }

  Future<void> requestPasswordReset(String email) async {
    try {
      if (baseUrl == null) {
        await _loadUrl();
      }

      final response = await http.post(
        Uri.parse('$baseUrl/users/forgot-password'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode({
          'email': email,
        }),
      );

      if (response.statusCode == 200) {
        return;
      }

      print('Failed to process password reset: ${response.statusCode}');
      print('Response body: ${response.body}');
      throw Exception('Failed to process password reset request');
    } catch (e) {
      print('Error processing password reset: $e');
      throw Exception('Failed to connect to server');
    }
  }
}