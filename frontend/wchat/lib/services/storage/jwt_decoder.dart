import 'package:jwt_decoder/jwt_decoder.dart' as jwt;
import 'storage_service.dart';
import 'package:wchat/services/storage/storage_service.dart';

class JwtDecoder {
  static final StorageService _storageService = StorageService();
  
  static Future<String?> getToken() async {
    return await _storageService.readSecureData('token');
  }

  static Future<Map<String, dynamic>> decode() async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No JWT token found in storage');
    }
    return jwt.JwtDecoder.decode(token);
  }

  static Future<bool> isExpired() async {
    final token = await getToken();
    if (token == null) {
      return true;
    }
    return jwt.JwtDecoder.isExpired(token);
  }

  // Get user ID from payload
  static Future<int?> getUserId() async {
    try {
      final payload = await decode();
      return payload['user_id'] as int?;
    } catch (e) {
      return null;
    }
  }

  // Get email from payload
  static Future<String?> getEmail() async {
    try {
      final payload = await decode();
      return payload['email'] as String?;
    } catch (e) {
      return null;
    }
  }

  // Get first name from payload
  static Future<String?> getFirstName() async {
    try {
      final payload = await decode();
      return payload['first_name'] as String?;
    } catch (e) {
      return null;
    }
  }

  // Get last name from payload
  static Future<String?> getLastName() async {
    try {
      final payload = await decode();
      return payload['last_name'] as String?;
    } catch (e) {
      return null;
    }
  }

  // Get role from payload
  static Future<String?> getRole() async {
    try {
      final payload = await decode();
      return payload['role'] as String?;
    } catch (e) {
      return null;
    }
  }

  // Get expiration timestamp from payload
  static Future<int?> getExpirationTime() async {
    try {
      final payload = await decode();
      return payload['exp'] as int?;
    } catch (e) {
      return null;
    }
  }

  // Get full name (convenience method)
  static Future<String?> getFullName() async {
    try {
      final firstName = await getFirstName();
      final lastName = await getLastName();
      if (firstName != null && lastName != null) {
        return '$firstName $lastName';
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}