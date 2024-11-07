import 'package:flutter/material.dart';
import 'package:wchat/services/api/message_api.dart';
import 'package:wchat/ui/Message/conversation_screen.dart';
import 'package:wchat/services/storage/jwt_decoder.dart';
import 'package:intl/intl.dart';
import 'package:wchat/ui/Home/app_drawer.dart';
import 'package:provider/provider.dart';
import 'package:wchat/services/webSocket/web_socket_provider.dart';
import 'package:wchat/data/app_theme.dart';

class MessageListScreen extends StatefulWidget {
  const MessageListScreen({Key? key}) : super(key: key);

  @override
  _MessageListScreenState createState() => _MessageListScreenState();
}

class _MessageListScreenState extends State<MessageListScreen> with SingleTickerProviderStateMixin {
  final MessageApi _messageApi = MessageApi();
  late WebSocketProvider _webSocketProvider;
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  int? _currentUserId;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadConversations();
    _initializeWebSocket();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeWebSocket() async {
    _webSocketProvider = Provider.of<WebSocketProvider>(context, listen: false);
    await _webSocketProvider.initializeWebSocket();

    _webSocketProvider.addListener(() {
      final messages = _webSocketProvider.messages;
      for (final message in messages) {
        if (message['type'] == 'new_conversation' || 
            message['type'] == 'message_update') {
          _loadConversations();
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
      _animationController.forward(from: 0);
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
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
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
    ).then((_) => _loadConversations());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadConversations(),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.05),
              AppColors.background,
            ],
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadConversations,
                color: AppColors.primary,
                child: _conversations.isEmpty
                    ? _buildEmptyState()
                    : _buildConversationsList(),
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
            size: 80,
            color: AppColors.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'No conversations yet',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your messages will appear here',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadConversations,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              (index / _conversations.length),
              ((index + 1) / _conversations.length),
              curve: Curves.easeOut,
            ),
          ),
        );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.5, 0),
              end: Offset.zero,
            ).animate(animation),
            child: _buildConversationTile(_conversations[index]),
          ),
        );
      },
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    final otherUserId = conversation['other_user_id'] as int;
    final firstName = conversation['first_name'] as String;
    final lastName = conversation['last_name'] as String;
    final lastMessage = conversation['last_message'] as String;
    final lastMessageTime = DateTime.parse(conversation['last_message_time']);
    final fullName = '$firstName $lastName';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        shadowColor: AppColors.primary.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppColors.primary.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () => _navigateToConversation(otherUserId, fullName),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    firstName[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _formatMessageTime(lastMessageTime),
                            style: TextStyle(
                              color: AppColors.textSecondary.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime messageTime) {
    final now = DateTime.now();
    final difference = now.difference(messageTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(messageTime);
    } else if (difference.inDays > 0) {
      return DateFormat('E').format(messageTime);
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
