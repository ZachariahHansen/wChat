import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:wchat/ui/Home/app_drawer.dart';
import 'package:wchat/data/models/shift.dart';
import 'package:wchat/data/models/notification.dart' as custom;
import 'package:wchat/services/api/shift_api.dart';
import 'package:wchat/services/api/pfp_api.dart';
import 'package:wchat/services/api/notification_api.dart';
import 'package:intl/intl.dart';
import 'package:wchat/data/app_theme.dart';
import 'package:wchat/services/storage/jwt_decoder.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Shift? _nextShift;
  bool _isLoading = true;
  final ShiftApi _shiftApi = ShiftApi();
  final ProfilePictureApi _pfpApi = ProfilePictureApi();
  final NotificationApi _notificationApi = NotificationApi();
  Uint8List? _profilePicture;
  int? _userId;
  List<custom.Notification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoadingNotifications = false;

  @override
  void initState() {
    super.initState();
    _fetchNextShift();
    _loadUserId().then((_) {
      _loadProfilePicture();
      _loadNotifications();
    });
  }

  Future<void> _loadNotifications() async {
    if (_userId == null) return;

    setState(() {
      _isLoadingNotifications = true;
    });

    try {
      final response = await _notificationApi.getNotifications(
        userId: _userId!,
        limit: 5,  // Show only latest 5 notifications
        unreadOnly: false,
      );

      setState(() {
        _notifications = response.notifications;
        _unreadCount = response.notifications.where((n) => !n.isRead).length;
        _isLoadingNotifications = false;
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _isLoadingNotifications = false;
      });
    }
  }

  Future<void> _markAsRead() async {
    if (_userId == null) return;

    try {
      await _notificationApi.markNotificationsRead(userId: _userId!);
      await _loadNotifications();  // Reload to update the UI
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }
   Future<void> _loadUserId() async {
  try {
    int? userId = await JwtDecoder.getUserId();
    if (userId == null) {
      throw Exception('User ID not found in JWT token');
    }
    setState(() {  
      _userId = userId;  
    });
  } catch (e) {
    print('Error loading user ID: $e');
  }
}

  Future<void> _loadProfilePicture() async {
    try {
      if (_userId == null) {
        throw Exception('User ID not found');
      }
      final pfp = await _pfpApi.getProfilePicture(_userId!);
      if (mounted) {
        setState(() {
          _profilePicture = pfp;
        });
      }
    } catch (e) {
      print('Error loading profile picture: $e');
    }
  }

  Future<void> _fetchNextShift() async {
    try {
      print('fetching next shift');
      final nextShift = await _shiftApi.getNextShift();
      setState(() {
        _nextShift = nextShift;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching next shift: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleProfileMenuSelection(String value) {
  if (_userId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to load user profile. Please try logging in again.'),
        backgroundColor: AppColors.error,
      ),
    );
    return;
  }

  switch (value) {
    case 'profile':
      Navigator.pushNamed(
        context,
        '/profile',
        arguments: _userId,
      );
      break;
    case 'settings':
      Navigator.pushNamed(context, '/settings');
      break;
    case 'logout':
      Navigator.pushReplacementNamed(context, '/login');
      break;
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        actions: [
          // Notification Bell
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 45),
              onSelected: (value) {
                if (value == 'mark_read') {
                  _markAsRead();
                }
              },
              child: Stack(
                children: [
                  const IconButton(
                    icon: Icon(Icons.notifications_outlined),
                    onPressed: null,
                  ),
                  if (_unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          _unreadCount.toString(),
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              itemBuilder: (BuildContext context) => [
                if (_isLoadingNotifications)
                  const PopupMenuItem<String>(
                    enabled: false,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_notifications.isEmpty)
                  const PopupMenuItem<String>(
                    enabled: false,
                    child: Text('No notifications'),
                  )
                else
                  ..._notifications.map((notification) => PopupMenuItem<String>(
                    enabled: false,
                    child: NotificationItem(notification: notification),
                  )).toList(),
                if (_notifications.isNotEmpty && _unreadCount > 0)
                  PopupMenuItem<String>(
                    value: 'mark_read',
                    child: const Text('Mark all as read'),
                  ),
              ],
            ),
          ),
          // Profile Menu
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 45),
              onSelected: _handleProfileMenuSelection,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: _profilePicture != null
                    ? MemoryImage(_profilePicture!)
                    : null,
                child: _profilePicture == null
                    ? const Icon(
                        Icons.person,
                        color: AppColors.textLight,
                      )
                    : null,
              ),
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'profile',
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(
                      'Profile',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'settings',
                  child: ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: Text(
                      'Settings',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: ListTile(
                    leading: const Icon(Icons.logout_outlined),
                    title: Text(
                      'Logout',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: _fetchNextShift,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CurrentTimeWidget(),
                const SizedBox(height: 16),
                _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : NextShiftWidget(nextShift: _nextShift),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CurrentTimeWidget extends StatelessWidget {
  const CurrentTimeWidget({Key? key}) : super(key: key);

  String _formatCurrentTime() {
    final now = DateTime.now();
    final formatter = DateFormat('EEEE, MMMM d, y\nh:mm a');
    return formatter.format(now);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Time',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _formatCurrentTime(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationItem extends StatelessWidget {
  final custom.Notification notification;

  const NotificationItem({
    Key? key,
    required this.notification,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: notification.isRead
            ? null
            : AppColors.primaryLight.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        title: Text(
          notification.content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: notification.isRead
                    ? FontWeight.normal
                    : FontWeight.bold,
              ),
        ),
        subtitle: Text(
          DateFormat('MMM d, y h:mm a')
              .format(notification.timeStamp),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        dense: true,
      ),
    );
  }
}

class NextShiftWidget extends StatelessWidget {
  final Shift? nextShift;
  const NextShiftWidget({Key? key, this.nextShift}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.work_outline,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Next Shift',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (nextShift != null)
              _buildShiftInfo(context)
            else
              Text(
                'No upcoming shifts',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftInfo(BuildContext context) {
    final DateFormat dateFormatter = DateFormat('EEEE, MMMM d, y');
    final DateFormat timeFormatter = DateFormat('h:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${timeFormatter.format(nextShift!.startTime)} - ${timeFormatter.format(nextShift!.endTime)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          dateFormatter.format(nextShift!.date),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildInfoChip(
              context,
              'Status',
              nextShift!.status,
              Icons.info_outline,
            ),
            const SizedBox(width: 12),
            _buildInfoChip(
              context,
              'Department',
              nextShift!.departmentName,
              Icons.business,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primaryLight.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}