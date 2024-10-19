import 'package:flutter/material.dart';
import 'package:wchat/data/models/message.dart';
import 'package:wchat/services/api/message_api.dart';
import 'package:wchat/services/auth_service.dart';

class ConversationScreen extends StatefulWidget {
  final int otherUserId;

  const ConversationScreen({Key? key, required this.otherUserId}) : super(key: key);

  @override
  _ConversationScreenState createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final MessageApi _messageApi = MessageApi();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  List<Message> _messages = [];
  int? _currentUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversation();
  }

  Future<void> _loadConversation() async {
    try {
      final token = await _authService.getToken();
      _currentUserId = await _authService.getUserIdFromToken(token);
      final conversation = await _messageApi.getConversation(_currentUserId!, widget.otherUserId);
      setState(() {
        _messages = conversation;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading conversation: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      try {
        final newMessage = await _messageApi.sendMessage(
          _currentUserId!,
          widget.otherUserId,
          _messageController.text,
        );
        setState(() {
          _messages.add(newMessage);
          _messageController.clear();
        });
      } catch (e) {
        print('Error sending message: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Conversation'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
                      return MessageBubble(
                        message: message,
                        isCurrentUser: message.sentByUserId == _currentUserId,
                      );
                    },
                  ),
                ),
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(width: 8.0),
          ElevatedButton(
            onPressed: _sendMessage,
            child: Text('Send'),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isCurrentUser;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isCurrentUser ? Colors.blue[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.content),
            SizedBox(height: 4.0),
            Text(
              message.timestamp.toString(),
              style: TextStyle(fontSize: 12.0, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}