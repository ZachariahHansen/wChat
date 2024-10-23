import 'package:flutter/material.dart';
import 'package:wchat/data/models/message.dart';
import 'package:wchat/services/api/message_api.dart';
import 'package:wchat/services/storage/jwt_decoder.dart';
import 'package:intl/intl.dart';
import 'package:wchat/services/webSocket/web_socket_provider.dart'; 
import 'package:provider/provider.dart';

class ConversationScreen extends StatefulWidget {
  final int otherUserId;
  final String otherUserName; // Add this to show the name in the AppBar

  const ConversationScreen({
    Key? key, 
    required this.otherUserId,
    required this.otherUserName,
  }) : super(key: key);

  @override
  _ConversationScreenState createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final MessageApi _messageApi = MessageApi();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late WebSocketProvider _webSocketProvider;
  
  List<Message> _messages = [];
  int? _currentUserId;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _setupWebSocket();
    _loadConversation();
  }

  void _setupWebSocket() {
    _webSocketProvider = Provider.of<WebSocketProvider>(context, listen: false);
    
    // Listen to WebSocket messages
    _webSocketProvider.addListener(() {
      final messages = _webSocketProvider.messages;
      for (final message in messages) {
        print('Received message: $message');
        if (message['type'] == 'new_message' && 
            message['message']['sent_by_user_id'] == widget.otherUserId) {
          _handleNewMessage(message['message']);
        }
      }
    });
  }

  void _handleNewMessage(Map<String, dynamic> messageData) {
    print('inside handle new message'); 
    print('messageData: $messageData'); // Debug log to see the incoming data
    
    final newMessage = Message.fromJson(messageData);

    setState(() {
      _messages.insert(0, newMessage);
    });
}

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation() async {
    try {
      _currentUserId = await JwtDecoder.getUserId();
      final messages = await _messageApi.getMessages(widget.otherUserId.toString());
      setState(() {
        _messages = messages.reversed.toList(); // Reverse the list since we're displaying newest first
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading conversation: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load messages. Please try again.');
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      print('Sending message: $content');
      final newMessage = await _messageApi.sendMessage(
        content,
        widget.otherUserId.toString(),
      );


      print('Chaning State');
      setState(() {
        _messages.insert(0, newMessage); // Add to the beginning since we're showing newest first
        _messageController.clear();
      });
      
      
      // Scroll to the bottom after sending
      print('Scrolling to the bottom');
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      print('Error sending message: $e');
      _showErrorSnackBar('Failed to send message. Please try again.');
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(child: Text('No messages yet'))
                      : ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
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
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 2,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8.0),
            ElevatedButton(
              onPressed: _isSending ? null : _sendMessage,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: const CircleBorder(),
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: isCurrentUser 
              ? Theme.of(context).primaryColor.withOpacity(0.2)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 1),
              blurRadius: 2,
              color: Colors.black.withOpacity(0.1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 4.0),
            Text(
              DateFormat('MMM d, h:mm a').format(message.timeStamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}