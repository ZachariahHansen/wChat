import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:wchat/services/storage/storage_service.dart';
import 'package:wchat/data/models/user.dart';
import 'dart:math';

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

  Future<List<User>> getAllUsers() async {
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
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load users');
    }
  }

  Future<User> getUserProfile(int userId) async {
    if (baseUrl == null) {
      await _loadUrl();
    }

    final token = await _storage.readSecureData('token');

    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
    );

    print("response code: ${response.statusCode}");

    if (response.statusCode == 200) {
      print("response body: ${response.body}");
      return User.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load user profile');
    }
  }

  Future<void> updateUserRole(int userId, String role) async {
    if (baseUrl == null) {
      await _loadUrl();
    }

    final token = await _storage.readSecureData('token');

    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId/role'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(<String, String>{
        'role_name': role,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update user role');
    }
  }

// This method returns the generated password
// TODO: add email service to send the password to the user
Future<String> createUser(Map<String, dynamic> userData) async {
  if (baseUrl == null) {
    await _loadUrl();
  }

  final password = _generateSecurePassword();
  
  final userDataWithPassword = {
    ...userData,
    'password': password,
  };

  final token = await _storage.readSecureData('token');

  final response = await http.post(
    Uri.parse('$baseUrl/users/register'),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode(userDataWithPassword),
  );

  if (response.statusCode != 201) {
    throw Exception('Failed to create user');
  }

  // Return the generated password
  return password;
}

String _generateSecurePassword() {
  final length = 12;
  final letterLowerCase = "abcdefghijklmnopqrstuvwxyz";
  final letterUpperCase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  final number = '0123456789';
  final special = '@#%^*>\$@?/[]=+';
  
  String chars = '';
  chars += letterLowerCase;
  chars += letterUpperCase;
  chars += number;
  chars += special;

  return List.generate(length, (index) {
    final indexRandom = Random.secure().nextInt(chars.length);
    return chars[indexRandom];
  }).join('');
}

  Future<void> updateUser(int userId, Map<String, dynamic> userData) async {
    if (baseUrl == null) {
      await _loadUrl();
    }

    final token = await _storage.readSecureData('token');

    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(userData),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update user');
    }
  }

  Future<void> deleteUser(int userId) async {
    if (baseUrl == null) {
      await _loadUrl();
    }

    final token = await _storage.readSecureData('token');

    final response = await http.delete(
      Uri.parse('$baseUrl/users/$userId'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete user');
    }
  }
}
