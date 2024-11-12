import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:wchat/data/models/user.dart';
import 'package:wchat/services/api/user_api.dart';
import 'package:wchat/services/api/pfp_api.dart';
import 'package:wchat/ui/Message/conversation_screen.dart';
import 'package:wchat/data/app_theme.dart';
import 'package:wchat/services/storage/jwt_decoder.dart';
import 'package:wchat/services/api/availability_api.dart';

class ProfileScreen extends StatefulWidget {
  final int userId;

  const ProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserApi _userApi = UserApi();
  final ProfilePictureApi _pfpApi = ProfilePictureApi();
  final AvailabilityApi _availabilityApi = AvailabilityApi();
  List<Map<String, dynamic>>? _availability;
  bool _isLoadingAvailability = false;

  Future<User>? _userFuture;
  Uint8List? _profilePicture;
  bool _isLoadingImage = false;
  bool _isCurrentUser = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _checkIfCurrentUser();
    _userFuture = _fetchUserProfile();
    await _loadProfilePicture();
    await _loadAvailability();
  }

   Future<void> _loadAvailability() async {
    if (mounted) {
      setState(() => _isLoadingAvailability = true);
    }

    try {
      final availability = await _availabilityApi.getAvailability(widget.userId);
      if (mounted) {
        setState(() {
          _availability = availability;
        });
      }
    } catch (e) {
      print('Error loading availability: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingAvailability = false);
      }
    }
  }

  Future<void> _checkIfCurrentUser() async {
    try {
      final currentUserId = await JwtDecoder.getUserId();
      if (mounted) {
        setState(() {
          _isCurrentUser = currentUserId == widget.userId;
        });
      }
    } catch (e) {
      print('Error checking current user: $e');
    }
  }

  Future<User> _fetchUserProfile() async {
    try {
      return await _userApi.getUserProfile(widget.userId);
    } catch (e) {
      print('Error fetching user profile: $e');
      rethrow;
    }
  }

  Future<void> _loadProfilePicture() async {
    if (mounted) {
      setState(() => _isLoadingImage = true);
    }

    try {
      final pictureData = await _pfpApi.getProfilePicture(widget.userId);
      if (mounted) {
        setState(() {
          _profilePicture = pictureData;
        });
      }
    } catch (e) {
      print('Error loading profile picture: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingImage = false);
      }
    }
  }


  void _navigateToEditProfile() {
    Navigator.pushNamed(
      context,
      '/edit-profile',
      arguments: widget.userId,
    ).then((_) {
      // Refresh profile data when returning from edit screen
      setState(() {
        _userFuture = _fetchUserProfile();
      });
    });
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _userFuture = _fetchUserProfile();
    });
    await _loadProfilePicture();
    await _loadAvailability();
  }

  Widget _buildAvailabilitySection() {
    final daysOfWeek = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];

    if (_isLoadingAvailability) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_availability == null || _availability!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'No availability set',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
        ),
      );
    }

    return Column(
      children: _availability!.map((day) {
        final dayIndex = day['day'] as int;
        final isAvailable = day['is_available'] as bool;

        if (!isAvailable) {
          return ListTile(
            leading: Icon(Icons.block, color: AppColors.error.withOpacity(0.7)),
            title: Text(
              daysOfWeek[dayIndex],
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: const Text('Not Available'),
          );
        }

        return ListTile(
          leading: Icon(Icons.schedule, color: AppColors.secondary),
          title: Text(
            daysOfWeek[dayIndex],
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            '${day['start_time']} - ${day['end_time']}',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
      ),
      body: FutureBuilder<User>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading profile',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshProfile,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text('User not found'),
            );
          }

          final user = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refreshProfile,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildProfileHeader(user),
                  _buildProfileContent(user),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(User user) {
  return Container(
    width: double.infinity,
    color: AppColors.primary,
    padding: const EdgeInsets.symmetric(vertical: 32.0),
    child: Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.textLight,
              width: 3,
            ),
          ),
          child: CircleAvatar(
            radius: 60,
            backgroundColor: AppColors.surface,
            backgroundImage: _profilePicture != null
                ? MemoryImage(_profilePicture!)
                : null,
            child: _isLoadingImage
                ? const CircularProgressIndicator(
                    color: AppColors.primary,
                  )
                : _profilePicture == null
                    ? Text(
                        '${user.firstName[0]}${user.lastName[0]}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${user.firstName} ${user.lastName}',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.textLight,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          user.role,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textLight.withOpacity(0.9),
              ),
        ),
        if (user.isManager)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.textLight.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Manager',
              style: TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    ),
  );
}

  Widget _buildProfileContent(User user) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSection(
            'Contact Information',
            [
              _buildInfoRow(Icons.email, 'Email', user.email),
              _buildInfoRow(Icons.phone, 'Phone', user.phoneNumber),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            'Work Information',
            [
              _buildInfoRow(
                Icons.attach_money,
                'Hourly Rate',
                '\$${user.hourlyRate.toStringAsFixed(2)}',
              ),
              _buildInfoRow(Icons.work, 'Role', user.role),
              _buildInfoRow(
                Icons.access_time,
                'Employment Type',
                user.fullTime ? 'Full Time' : 'Part Time',
              ),
              if (user.departments.isNotEmpty)
                _buildDepartmentsList(user.departments),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            'Weekly Availability',
            [_buildAvailabilitySection()],
          ),
          const SizedBox(height: 24),
          if (_isCurrentUser) ...[
            ElevatedButton.icon(
              onPressed: _navigateToEditProfile,
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/availability')
                    .then((_) => _loadAvailability());
              },
              icon: const Icon(Icons.event_available),
              label: const Text('Edit Availability'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ] else
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConversationScreen(
                      otherUserId: widget.userId,
                      otherUserName: '${user.firstName} ${user.lastName}',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.message),
              label: const Text('Message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.all(16),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentsList(List<String> departments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Departments',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: departments.map((department) {
            return Chip(
              avatar: const Icon(
                Icons.business,
                size: 18,
                color: AppColors.primary,
              ),
              label: Text(department),
              backgroundColor: AppColors.primary.withOpacity(0.1),
              labelStyle: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
