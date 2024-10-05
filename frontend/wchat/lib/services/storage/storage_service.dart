// storage_service.dart
import 'storage_service_web.dart' if (dart.library.io) 'storage_service_mobile.dart';

abstract class StorageService {
  Future<void> writeSecureData(String key, String value);
  Future<String?> readSecureData(String key);
  Future<void> deleteSecureData(String key);

  factory StorageService() => getStorageService();
}