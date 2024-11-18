import 'package:flutter/material.dart';
import 'package:wchat/data/models/message.dart';
import 'package:wchat/services/api/message_api.dart';
import 'package:wchat/services/storage/jwt_decoder.dart';
import 'package:intl/intl.dart';
import 'package:wchat/services/webSocket/web_socket_provider.dart';
import 'package:provider/provider.dart';
import 'package:wchat/data/app_theme.dart';

class ConversationScreen extends StatefulWidget {
  final int otherUserId;
  final String otherUserName;

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
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherUserName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textLight,
              ),
            ),
            Text(
              _isLoading ? 'Loading...' : '${_messages.length} messages',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textLight.withOpacity(0.7),
              ),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          CircleAvatar(
            backgroundColor: AppColors.primaryLight,
            child: Text(
              widget.otherUserName.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.1),
              AppColors.background,
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _messages.isEmpty
                      ? _buildEmptyState()
                      : _buildMessageList(),
            ),
            _buildMessageInput(),
          ],
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
            Icons.chat_bubble_outline,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation!',
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isCurrentUser = message.sentByUserId == _currentUserId;
        final showDate = index == _messages.length - 1 ||
            !_isSameDay(_messages[index].timeStamp, _messages[index + 1].timeStamp);

        return Column(
          children: [
            if (showDate) _buildDateDivider(message.timeStamp),
            MessageBubble(
              message: message,
              isCurrentUser: isCurrentUser,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateDivider(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.textSecondary.withOpacity(0.2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _formatMessageDate(date),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppColors.textSecondary.withOpacity(0.2))),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -4),
            blurRadius: 8,
            color: AppColors.textSecondary.withOpacity(0.1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSending ? null : _sendMessage,
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _isSending
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.textLight),
                            ),
                          )
                        : Icon(
                            Icons.send,
                            color: AppColors.textLight,
                            size: 24,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatMessageDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      return 'Yesterday';
    }
    return DateFormat('MMMM d, y').format(date);
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
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isCurrentUser ? 48 : 0,
          right: isCurrentUser ? 0 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isCurrentUser ? 20 : 4),
            bottomRight: Radius.circular(isCurrentUser ? 4 : 20),
          ),
          border: Border.all(
            color: isCurrentUser
                ? AppColors.primary.withOpacity(0.2)
                : AppColors.textSecondary.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('h:mm a').format(message.timeStamp),
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}