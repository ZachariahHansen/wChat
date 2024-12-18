import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:wchat/services/storage/storage_service.dart';
import 'package:http_parser/http_parser.dart';

class ProfilePictureApi {
  String? baseUrl;
  final StorageService _storage = StorageService();

  ProfilePictureApi() {
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final String response = await rootBundle.loadString('lib/data/config.json');
    final data = await json.decode(response);
    baseUrl = data['pfp_url'];
    print("Profile Picture API URL: $baseUrl");
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
        Uri.parse('$baseUrl/users/$userId/profile-picture'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // The Lambda returns base64 encoded image data
        if (response.headers['content-type']?.startsWith('image/') ?? false) {
          return response.bodyBytes;
        } else {
          // Handle case where response is base64 encoded
          final Map<String, dynamic> data = json.decode(response.body);
          if (data['isBase64Encoded'] == true) {
            return base64.decode(data['body']);
          }
        }
      } else if (response.statusCode == 404) {
        print('No profile picture found');
        return null;
      }

      throw Exception('Failed to load profile picture: ${response.statusCode}');
    } catch (e) {
      print('Error fetching profile picture: $e');
      return null;
    }
  }

  Future<bool> uploadProfilePicture(
      int userId, Uint8List imageBytes, String contentType) async {
    try {
      if (baseUrl == null) {
        await _loadUrl();
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      // Ensure content type is valid
      if (!['image/jpeg', 'image/png'].contains(contentType)) {
        throw Exception(
            'Invalid content type. Must be image/jpeg or image/png');
      }

      // Create a regular PUT request with binary data
      final response = await http.put(
        Uri.parse('$baseUrl/users/$userId/profile-picture'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': contentType,
          'Accept': '*/*',
          'x-content-type': contentType,
        },
        body: imageBytes,
      );

      if (response.statusCode == 200) {
        return true;
      }

      final errorResponse = json.decode(response.body);
      print('Failed to upload profile picture: ${errorResponse['error']}');
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
        Uri.parse('$baseUrl/users/$userId/profile-picture'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return true;
      }

      final errorResponse = json.decode(response.body);
      print('Failed to delete profile picture: ${errorResponse['error']}');
      return false;
    } catch (e) {
      print('Error deleting profile picture: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>?> getAllProfilePictures() async {
    try {
      if (baseUrl == null) {
        await _loadUrl();
      }

      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/users/all/profile-pictures'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<Map<String, dynamic>> profilePictures =
            (data['profile_pictures'] as List).map((picture) {
          // Convert the base64 string to Uint8List for immediate use
          final Uint8List imageBytes = base64.decode(picture['image_data']);

          return {
            'user_id': picture['user_id'],
            'content_type': picture['content_type'],
            'image_bytes': imageBytes,
          };
        }).toList();

        return profilePictures;
      } else if (response.statusCode == 404) {
        print('No profile pictures found');
        return [];
      }

      throw Exception(
          'Failed to load profile pictures: ${response.statusCode}');
    } catch (e) {
      print('Error fetching profile pictures: $e');
      return null;
    }
  }
}
