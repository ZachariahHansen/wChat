import 'dart:convert';
// import 'dart:ffi';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:wchat/services/storage/storage_service.dart';
import 'package:wchat/data/models/message.dart';

class MessageApi {
  String? baseUrl;
  final StorageService _storage = StorageService();

  MessageApi() {
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final String response = await rootBundle.loadString('lib/data/config.json');
    final data = await json.decode(response);
    baseUrl = data['base_url'];
    print("base url: $baseUrl");
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _storage.readSecureData('token');
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  // Get list of conversations
  Future<List<Map<String, dynamic>>> getConversations() async {
    if (baseUrl == null) {
      await _loadUrl();
    }

    final response = await http.get(
      Uri.parse('$baseUrl/messages/conversations'),
      headers: await _getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data);
    } else {
      throw Exception('Failed to load conversations: ${response.statusCode}');
    }
  }

  // Get messages for a specific conversation
  Future<List<Message>> getMessages(String otherUserId) async {
    if (baseUrl == null) {
      await _loadUrl();
    }

    final response = await http.get(
      Uri.parse('$baseUrl/messages/$otherUserId'),
      headers: await _getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Message.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load messages: ${response.statusCode}');
    }
  }

  // Send a new message
  Future<Message> sendMessage(String content, String receivedByUserId) async {
    if (baseUrl == null) {
      await _loadUrl();
    }

    int? receivedByUserIdParsed = int.tryParse(receivedByUserId);

    final response = await http.post(
      Uri.parse('$baseUrl/messages'),
      headers: await _getAuthHeaders(),
      body: jsonEncode({
        'content': content,
        'received_by_user_id': receivedByUserIdParsed,
      }),
    );

    if (response.statusCode == 201) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Message.fromJson(data);
    } else {
      throw Exception('Failed to send message: ${response.statusCode}');
    }
  }

  // Update a message
  Future<Message> updateMessage(String messageId, String content) async {
    if (baseUrl == null) {
      await _loadUrl();
    }

    final response = await http.put(
      Uri.parse('$baseUrl/messages/$messageId'),
      headers: await _getAuthHeaders(),
      body: jsonEncode({
        'content': content,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return Message.fromJson(data);
    } else {
      throw Exception('Failed to update message: ${response.statusCode}');
    }
  }

  // Delete a message
  Future<void> deleteMessage(String messageId) async {
    if (baseUrl == null) {
      await _loadUrl();
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/messages/$messageId'),
      headers: await _getAuthHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete message: ${response.statusCode}');
    }
  }
}