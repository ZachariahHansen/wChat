import 'package:jwt_decoder/jwt_decoder.dart' as jwt;
import 'storage_service.dart';
import 'package:wchat/services/storage/storage_service.dart';

class JwtDecoder {
  static final StorageService _storageService = StorageService();
  

  static Future<String?> _getToken() async {
    return await _storageService.readSecureData('token');
  }

  static Future<Map<String, dynamic>> decode() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No JWT token found in storage');
    }
    return jwt.JwtDecoder.decode(token);
  }

  static Future<bool> isExpired() async {
    final token = await _getToken();
    if (token == null) {
      return true;
    }
    return jwt.JwtDecoder.isExpired(token);
  }
}
