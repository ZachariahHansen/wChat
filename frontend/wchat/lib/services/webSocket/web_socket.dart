import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:flutter/services.dart' show rootBundle;
import 'package:wchat/services/storage/jwt_decoder.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  WebSocketChannel? _channel;
  String? webSocketUrl;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  bool _isConnected = false;
  
  // Singleton pattern
  factory WebSocketService() {
    return _instance;
  }

  Future<void> _loadUrl() async {
    final String response = await rootBundle.loadString('lib/data/config.json');
    final data = await json.decode(response);
    webSocketUrl = data['websocket_url'];
    print("base url: $webSocketUrl");
  }
  
  WebSocketService._internal();

  bool get isConnected => _isConnected;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  Future<void> connect() async {
    if (_isConnected) return;

    if (webSocketUrl == null) {
      await _loadUrl();
    }

    try {
      final userId = await JwtDecoder.getUserId(); 

      final baseUri = Uri.parse(webSocketUrl!);

      final wsUri = baseUri.replace(
        queryParameters: {'user_id': userId.toString()}
      );
      
      print('Attempting to connect to WebSocket at: $wsUri'); 
      
      _channel = WebSocketChannel.connect(wsUri);
      
      await _channel?.ready;
      
      _isConnected = true;
      print('WebSocket connected successfully');

      _channel?.stream.listen(
        (dynamic message) {
          print('Received WebSocket message: $message'); 
          final decodedMessage = json.decode(message as String);
          _messageController.add(decodedMessage);
        },
        onError: (error) {
          print('WebSocket Error: $error');
          _handleDisconnect();
        },
        onDone: () {
          print('WebSocket connection closed');
          _handleDisconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('WebSocket Connection Error: $e');
      _handleDisconnect();
      rethrow;
    }
}

  void sendMessage(Map<String, dynamic> message) {
    if (!_isConnected) {
      throw Exception('WebSocket not connected');
    }
    
    final encodedMessage = json.encode(message);
    _channel?.sink.add(encodedMessage);
  }

  void _handleDisconnect() {
    _isConnected = false;
    _channel?.sink.close(status.goingAway);
    _channel = null;
  }

  Future<void> disconnect() async {
    if (!_isConnected) return;
    
    _handleDisconnect();
    await _messageController.close();
  }

  // Method to reconnect if connection is lost
  Future<void> reconnect() async {
    if (_isConnected) return;
    
    await connect();
  }
}