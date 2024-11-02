import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:wchat/data/models/user.dart';
import 'package:wchat/services/api/user_api.dart';
import 'package:wchat/services/api/profile_api.dart';
import 'package:wchat/ui/Message/conversation_screen.dart';
import 'package:wchat/data/app_theme.dart';
import 'package:image_picker/image_picker.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;
  final bool isCurrentUser;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.isCurrentUser = false,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final UserApi _userApi = UserApi();
  final ProfileApi _profileApi = ProfileApi();
  final ImagePicker _imagePicker = ImagePicker();

  Future<User>? _profileFuture;
  Uint8List? _profilePicture;
  bool _isLoadingImage = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchProfile();
    _loadProfilePicture();
  }

  Future<User> _fetchProfile() async {
    return await _userApi.getUserProfile(widget.userId);
  }

  Future<void> _loadProfilePicture() async {
    setState(() => _isLoadingImage = true);
    try {
      final pictureData = await _profileApi.getProfilePicture(widget.userId);
      if (mounted) {
        setState(() {
          _profilePicture = pictureData;
          _isLoadingImage = false;
        });
      }
    } catch (e) {
      print('Error loading profile picture: $e');
      if (mounted) {
        setState(() => _isLoadingImage = false);
      }
    }
  }

  Future<void> _updateProfilePicture() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image == null) return;

      setState(() => _isLoadingImage = true);

      final imageBytes = await image.readAsBytes();
      final contentType = image.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      final success = await _profileApi.uploadProfilePicture(
        widget.userId,
        imageBytes,
        contentType,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully')),
        );
        _loadProfilePicture();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile picture')),
        );
      }
    } catch (e) {
      print('Error updating profile picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile picture')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingImage = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (widget.isCurrentUser)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // TODO: Implement edit profile functionality
              },
            ),
        ],
      ),
      body: FutureBuilder<User>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(color: AppColors.error),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text('No profile data found'),
            );
          }

          final user = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _profileFuture = _fetchProfile();
              });
              await _loadProfilePicture();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildProfileHeader(user),
                  _buildProfileDetails(user),
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
      padding: const EdgeInsets.only(top: 32, bottom: 24),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
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
                      ? const CircularProgressIndicator()
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
              if (widget.isCurrentUser)
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: Material(
                    color: AppColors.secondary,
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      onTap: _updateProfilePicture,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.camera_alt,
                          color: AppColors.textLight,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${user.firstName} ${user.lastName}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            user.role,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
              child: Text(
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

  Widget _buildProfileDetails(User user) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoSection(
            title: 'Contact Information',
            children: [
              _buildInfoRow(Icons.email, 'Email', user.email),
              _buildInfoRow(Icons.phone, 'Phone', user.phoneNumber),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoSection(
            title: 'Work Information',
            children: [
              _buildInfoRow(
                Icons.attach_money,
                'Hourly Rate',
                '\$${user.hourlyRate.toStringAsFixed(2)}',
              ),
              _buildInfoRow(
                Icons.work,
                'Role',
                user.role,
              ),
            ],
          ),
          if (user.departments.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildDepartmentsSection(user.departments),
          ],
          if (!widget.isCurrentUser) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
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
                  padding: const EdgeInsets.all(16),
                  backgroundColor: AppColors.primary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
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
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentsSection(List<String> departments) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Departments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: departments.map((department) {
                return Chip(
                  avatar: Icon(
                    Icons.business,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: Text(department),
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}