import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:wchat/services/storage/storage_service.dart';
import 'package:wchat/data/models/notification.dart';

class NotificationApi {
  String? baseUrl;
  final StorageService _storage = StorageService();

  NotificationApi() {
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

  // Get notifications with optional filtering and pagination
  Future<NotificationResponse> getNotifications({
    required int userId,
    int limit = 50,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final queryParams = {
      'userId': userId.toString(),
      'limit': limit.toString(),
      'offset': offset.toString(),
      'unreadOnly': unreadOnly.toString(),
    };

    final uri = Uri.parse('$baseUrl/notifications').replace(
      queryParameters: queryParams,
    );

    print(uri);

    final response = await http.get(
      uri,
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return NotificationResponse.fromJson(data);
    } else {
      throw Exception('Failed to load notifications');
    }
  }

  // Mark specific notifications as read
  Future<List<int>> markNotificationsRead({
    required int userId,
    List<int>? notificationIds,
  }) async {
    if (baseUrl == null) await _loadUrl();
    final headers = await _getHeaders();

    final response = await http.put(
      Uri.parse('$baseUrl/notifications'),
      headers: headers,
      body: json.encode({
        'userId': userId,
        if (notificationIds != null) 'notificationIds': notificationIds,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<int>.from(data['updatedIds']);
    } else {
      throw Exception('Failed to mark notifications as read');
    }
  }
}

// Response model for notifications with pagination
class NotificationResponse {
  final List<Notification> notifications;
  final PaginationInfo pagination;

  NotificationResponse({
    required this.notifications,
    required this.pagination,
  });

  factory NotificationResponse.fromJson(Map<String, dynamic> json) {
    return NotificationResponse(
      notifications: (json['notifications'] as List)
          .map((notification) => Notification.fromJson(notification))
          .toList(),
      pagination: PaginationInfo.fromJson(json['pagination']),
    );
  }
}

class PaginationInfo {
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  PaginationInfo({
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      total: json['total'],
      limit: json['limit'],
      offset: json['offset'],
      hasMore: json['hasMore'],
    );
  }
}