// storage_service_web.dart
import 'dart:html' as html;
import 'storage_service.dart';

class StorageServiceWeb implements StorageService {
  @override
  Future<void> writeSecureData(String key, String value) async {
    html.window.localStorage[key] = value;
  }

  @override
  Future<String?> readSecureData(String key) async {
    return html.window.localStorage[key];
  }

  @override
  Future<void> deleteSecureData(String key) async {
    html.window.localStorage.remove(key);
  }
}

StorageService getStorageService() => StorageServiceWeb();