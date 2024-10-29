
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:wchat/services/storage/storage_service.dart';
import 'package:wchat/data/models/role.dart';


class RoleApi {
  String? baseUrl;
  final StorageService _storage = StorageService();

  RoleApi() {
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final String response = await rootBundle.loadString('lib/data/config.json');
    final data = await json.decode(response);
    baseUrl = data['base_url'];
    print("base url: $baseUrl");
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.readSecureData('token');
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Role>> getAllRoles() async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/roles/all'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Role.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load roles');
    }
  }

  Future<Role> getRole(int roleId) async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/roles/$roleId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return Role.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load role');
    }
  }

  Future<int> createRole(String name, String description) async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/roles'),
      headers: headers,
      body: json.encode({
        'name': name,
        'description': description,
      }),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body)['id'];
    } else {
      throw Exception('Failed to create role');
    }
  }

  Future<void> updateRole(int roleId, {String? name, String? description}) async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final Map<String, String> updates = {};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;

    final response = await http.put(
      Uri.parse('$baseUrl/roles/$roleId'),
      headers: headers,
      body: json.encode(updates),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update role');
    }
  }

  Future<void> deleteRole(int roleId) async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.delete(
      Uri.parse('$baseUrl/roles/$roleId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete role');
    }
  }
}