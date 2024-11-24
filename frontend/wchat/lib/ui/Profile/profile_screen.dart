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
          child: CircularProgressIndicator(color: AppColors.primary),
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

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isAvailable ? AppColors.surface : AppColors.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isAvailable ? AppColors.primary.withOpacity(0.2) : AppColors.error.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isAvailable ? Icons.schedule : Icons.block,
                color: isAvailable ? AppColors.secondary : AppColors.error.withOpacity(0.7),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      daysOfWeek[dayIndex],
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    if (isAvailable)
                      Text(
                        '${day['start_time']} - ${day['end_time']}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      )
                    else
                      Text(
                        'Not Available',
                        style: TextStyle(
                          color: AppColors.error.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: FutureBuilder<User>(
          future: _userFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textLight,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: Text('User not found'));
            }

            final user = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _refreshProfile,
              child: CustomScrollView(
                slivers: [
                  _buildAppBar(user),
                  SliverToBoxAdapter(
                    child: _buildProfileContent(user),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(User user) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'profile-${widget.userId}',
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.textLight,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: AppColors.surface,
                      backgroundImage: _profilePicture != null
                          ? MemoryImage(_profilePicture!)
                          : null,
                      child: _isLoadingImage
                          ? const CircularProgressIndicator(color: AppColors.primary)
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
                ),
                const SizedBox(height: 16),
                Text(
                  '${user.firstName} ${user.lastName}',
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user.role,
                  style: TextStyle(
                    color: AppColors.textLight.withOpacity(0.9),
                    fontSize: 16,
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
          ),
        ),
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
            _buildActionButton(
              onPressed: _navigateToEditProfile,
              icon: Icons.edit,
              label: 'Edit Profile',
              color: AppColors.secondary,
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              onPressed: () {
                Navigator.pushNamed(context, '/availability')
                    .then((_) => _loadAvailability());
              },
              icon: Icons.event_available,
              label: 'Edit Availability',
              color: AppColors.primary,
            ),
          ] else
            _buildActionButton(
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
              icon: Icons.message,
              label: 'Message',
              color: AppColors.primary,
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.textSecondary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
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
                    fontWeight: FontWeight.w500,
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
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.business,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    department,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: AppColors.textLight,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
