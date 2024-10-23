// lib/providers/websocket_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wchat/services/webSocket/web_socket.dart';

class WebSocketProvider extends ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService();
  StreamSubscription? _messageSubscription;
  bool get isConnected => _webSocketService.isConnected;
  
  // Store messages in memory if needed
  final List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> get messages => _messages;

  Future<void> initializeWebSocket() async {
    if (!_webSocketService.isConnected) {
      await _webSocketService.connect();
      print('WebSocket connected');
      _messageSubscription = _webSocketService.messageStream.listen(
        (message) {
          _handleMessage(message);
          notifyListeners();
        },
        onError: (error) {
          print('WebSocket Error in Provider: $error');
          _handleReconnect();
        },
      );
    }
  }

  void _handleMessage(Map<String, dynamic> message) {
    _messages.add(message);
    // Handle different message types
    switch (message['type']) {
      case 'shift_update':
        // Notify specific listeners about shift updates
        break;
      case 'chat_message':
        // Handle chat messages
        break;
      // Add other message type handlers
    }
  }

  Future<void> _handleReconnect() async {
    await Future.delayed(const Duration(seconds: 5));
    try {
      await _webSocketService.reconnect();
    } catch (e) {
      print('Reconnection failed: $e');
      _handleReconnect();
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    _webSocketService.sendMessage(message);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _webSocketService.disconnect();
    super.dispose();
  }
}
