import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:wchat/services/storage/storage_service.dart';

class LoginApi {
  String? baseUrl;
  final StorageService _storage = StorageService();

  LoginApi() {
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final String response = await rootBundle.loadString('lib/data/config.json');
    final data = await json.decode(response);
    baseUrl = data['base_url'];
    print("base url: $baseUrl");
  }


  Future<int> login_service(String email, String password) async {

    if (baseUrl == null) {
      await _loadUrl();
    }

    final response = await http.post(
      Uri.parse('$baseUrl/users/login'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'email': email,
        'password': password,
      }),
    );

    print(response);

    if (response.statusCode == 200) {
      print("response body: ${response.body}");
      print("response code: ${response.statusCode}");

      final Map<String, dynamic> data = json.decode(response.body);
      final String token = data['token'];

      await _storage.writeSecureData('token', token);

      // final storage = const FlutterSecureStorage();
      // await storage.write(key: 'token', value: response.body);
    }

    print("status code: ${response.statusCode}");
    return response.statusCode;
  }
}