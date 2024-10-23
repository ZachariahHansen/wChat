import 'package:flutter/material.dart';
import 'package:wchat/services/api/message_api.dart';
import 'package:wchat/ui/Message/conversation_screen.dart';
import 'package:wchat/services/storage/jwt_decoder.dart';
import 'package:intl/intl.dart';
import 'package:wchat/ui/Home/app_drawer.dart';
import 'package:provider/provider.dart';
import 'package:wchat/services/webSocket/web_socket_provider.dart';

class MessageListScreen extends StatefulWidget {
  const MessageListScreen({Key? key}) : super(key: key);

  @override
  _MessageListScreenState createState() => _MessageListScreenState();
}

class _MessageListScreenState extends State<MessageListScreen> {
  final MessageApi _messageApi = MessageApi();
  late WebSocketProvider _webSocketProvider;
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _initializeWebSocket();
  }

  Future<void> _initializeWebSocket() async {
    _webSocketProvider = Provider.of<WebSocketProvider>(context, listen: false);
    
    
    await _webSocketProvider.initializeWebSocket();

    // Listen to WebSocket messages
    _webSocketProvider.addListener(() {
      final messages = _webSocketProvider.messages;
      for (final message in messages) {
        if (message['type'] == 'new_conversation' || 
            message['type'] == 'message_update') {
          _loadConversations(); // Reload the conversation list
          break;
        }
      }
    });
  }

  Future<void> _loadConversations() async {
    try {
      _currentUserId = await JwtDecoder.getUserId();
      final conversations = await _messageApi.getConversations();
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading conversations: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load conversations. Please try again.');
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

  void _navigateToConversation(int otherUserId, String otherUserName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationScreen(
          otherUserId: otherUserId,
          otherUserName: otherUserName,
        ),
      ),
    ).then((_) => _loadConversations()); // Reload conversations when returning
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadConversations(),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadConversations,
              child: _conversations.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: _conversations.length,
                      itemBuilder: (context, index) {
                        return _buildConversationTile(_conversations[index]);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your messages will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    final otherUserId = conversation['other_user_id'] as int;
    final firstName = conversation['first_name'] as String;
    final lastName = conversation['last_name'] as String;
    final lastMessage = conversation['last_message'] as String;
    final lastMessageTime = DateTime.parse(conversation['last_message_time']);
    final fullName = '$firstName $lastName';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            firstName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          fullName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          lastMessage,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatMessageTime(lastMessageTime),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        onTap: () => _navigateToConversation(otherUserId, fullName),
      ),
    );
  }

  String _formatMessageTime(DateTime messageTime) {
    final now = DateTime.now();
    final difference = now.difference(messageTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(messageTime);
    } else if (difference.inDays > 0) {
      return DateFormat('E').format(messageTime); // Day name
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

// Message preview card widget for better organization
class MessagePreviewCard extends StatelessWidget {
  final String userName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final VoidCallback onTap;

  const MessagePreviewCard({
    Key? key,
    required this.userName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(
          userName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          lastMessage,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          _formatTime(lastMessageTime),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(time);
    } else if (messageDate.isAfter(today.subtract(const Duration(days: 7)))) {
      return DateFormat('E').format(time); // Day name
    } else {
      return DateFormat('MMM d').format(time);
    }
  }
}