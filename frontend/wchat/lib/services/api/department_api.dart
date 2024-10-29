import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:wchat/services/storage/storage_service.dart';
import 'package:wchat/data/models/department.dart';


class DepartmentApi {
  String? baseUrl;
  final StorageService _storage = StorageService();

  DepartmentApi() {
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

  // Get a specific department with its users
  Future<Department> getDepartment(int departmentId) async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/departments/$departmentId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return Department.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load department');
    }
  }

  // Create a new department
  Future<int> createDepartment(String name, String description) async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/departments'),
      headers: headers,
      body: json.encode({
        'name': name,
        'description': description,
      }),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body)['id'];
    } else {
      throw Exception('Failed to create department');
    }
  }

  // Update an existing department
  Future<void> updateDepartment(int departmentId, {String? name, String? description}) async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final Map<String, String> updates = {};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;

    final response = await http.put(
      Uri.parse('$baseUrl/departments/$departmentId'),
      headers: headers,
      body: json.encode(updates),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update department');
    }
  }

  // Delete a department
  Future<void> deleteDepartment(int departmentId) async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.delete(
      Uri.parse('$baseUrl/departments/$departmentId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete department');
    }
  }

  // Assign a user to a department
  Future<void> assignUserToDepartment(int userId, int departmentId) async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/assign-department'),
      headers: headers,
      body: json.encode({
        'user_id': userId,
        'department_id': departmentId,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to assign user to department');
    }
  }

  // Remove a user from a department
  Future<void> removeUserFromDepartment(int userId, int departmentId) async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.delete(
      Uri.parse('$baseUrl/assign-department/$departmentId/user/$userId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove user from department');
    }
  }

  // Get all departments
  Future<List<Department>> getAllDepartments() async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.get(
      Uri.parse('$baseUrl/departments/all'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Department.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load departments');
    }
  }
}