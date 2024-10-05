// storage_service_mobile.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'storage_service.dart';

class StorageServiceMobile implements StorageService {
  final _storage = FlutterSecureStorage();

  @override
  Future<void> writeSecureData(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<String?> readSecureData(String key) async {
    return await _storage.read(key: key);
  }

  @override
  Future<void> deleteSecureData(String key) async {
    await _storage.delete(key: key);
  }
}

StorageService getStorageService() => StorageServiceMobile();