import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:wchat/services/storage/storage_service.dart';

class UserApi {
  String? baseUrl;
  final StorageService _storage = StorageService();

  UserApi() {
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final String response = await rootBundle.loadString('lib/data/config.json');
    final data = await json.decode(response);
    baseUrl = data['base_url'];
    print("base url: $baseUrl");
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    if (baseUrl == null) {
      await _loadUrl();
    }

    final token = await _storage.readSecureData('token');

    final response = await http.get(
      Uri.parse('$baseUrl/users/all'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
    );

    print("response code: ${response.statusCode}");

    if (response.statusCode == 200) {
      print("response body: ${response.body}");
      final List<dynamic> data = json.decode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load users');
    }
  }
}