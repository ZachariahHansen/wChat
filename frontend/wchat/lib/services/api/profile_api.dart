import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:wchat/services/storage/storage_service.dart';

class ProfileApi {
  String? baseUrl;
  final StorageService _storage = StorageService();

  ProfileApi() {
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

  // Get profile picture
  Future<Uint8List?> getProfilePicture(int userId) async {
    try {
      if (baseUrl == null) {
        await _loadUrl();
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/profile-picture/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else if (response.statusCode == 404) {
        return null;
      }
      
      throw Exception('Failed to load profile picture: ${response.statusCode}');
    } catch (e) {
      print('Error fetching profile picture: $e');
      return null;
    }
  }

  // Upload profile picture
  Future<bool> uploadProfilePicture(int userId, Uint8List imageBytes, String contentType) async {
    try {
      if (baseUrl == null) {
        await _loadUrl();
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/profile-picture/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': contentType,
        },
        body: imageBytes,
      );

      if (response.statusCode == 200) {
        return true;
      }

      print('Failed to upload profile picture: ${response.statusCode}');
      return false;
    } catch (e) {
      print('Error uploading profile picture: $e');
      return false;
    }
  }

  // Delete profile picture
  Future<bool> deleteProfilePicture(int userId) async {
    try {
      if (baseUrl == null) {
        await _loadUrl();
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/profile-picture/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return true;
      }

      print('Failed to delete profile picture: ${response.statusCode}');
      return false;
    } catch (e) {
      print('Error deleting profile picture: $e');
      return false;
    }
  }

  // Update user profile
  Future<bool> updateProfile(int userId, Map<String, dynamic> updateData) async {
    try {
      if (baseUrl == null) {
        await _loadUrl();
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.put(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(updateData),
      );

      if (response.statusCode == 200) {
        return true;
      }

      print('Failed to update profile: ${response.statusCode}');
      return false;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }
}