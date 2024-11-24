import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:wchat/data/models/user.dart';
import 'package:wchat/services/api/user_api.dart';
import 'package:wchat/services/api/pfp_api.dart';
import 'package:wchat/data/app_theme.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  final int userId;

  const EditProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final UserApi _userApi = UserApi();
  final ProfilePictureApi _pfpApi = ProfilePictureApi();
  final ImagePicker _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingImage = false;
  Uint8List? _profilePicture;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadProfilePicture();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);
      final user = await _userApi.getUserProfile(widget.userId);

      if (mounted) {
        setState(() {
          _firstNameController.text = user.firstName;
          _lastNameController.text = user.lastName;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load user data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadProfilePicture() async {
    try {
      setState(() => _isLoadingImage = true);
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

      final success = await _pfpApi.uploadProfilePicture(
        widget.userId,
        imageBytes,
        contentType,
      );

      if (success) {
        await _loadProfilePicture();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to update profile picture');
      }
    } catch (e) {
      print('Error updating profile picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update profile picture'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingImage = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      // Update display name
      final nameUpdateSuccess = await _userApi.updateName(
        widget.userId,
        {
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
        },
      );

      // Update password if provided
      bool passwordUpdateSuccess = true;
      if (_currentPasswordController.text.isNotEmpty) {
        passwordUpdateSuccess = await _userApi.updatePassword(
          widget.userId,
          _currentPasswordController.text,
          _newPasswordController.text,
        );
      }

      if (nameUpdateSuccess && passwordUpdateSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      print('Error saving changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        elevation: 0,
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
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProfilePictureSection(),
                      _buildDisplayNameSection(),
                      _buildPasswordSection(),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: AppColors.textSecondary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Hero(
            tag: 'profile-${widget.userId}',
            child: SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary,
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      backgroundImage: _profilePicture != null
                          ? MemoryImage(_profilePicture!)
                          : null,
                      child: _isLoadingImage
                          ? const CircularProgressIndicator(
                              color: AppColors.primary,
                            )
                          : _profilePicture == null
                              ? Text(
                                  '${_firstNameController.text.isNotEmpty ? _firstNameController.text[0] : ''}${_lastNameController.text.isNotEmpty ? _lastNameController.text[0] : ''}',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                )
                              : null,
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Material(
                      color: AppColors.secondary,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: InkWell(
                        onTap: _updateProfilePicture,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(10.0),
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
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap the camera icon to change your profile picture',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayNameSection() {
    return Container(
      margin: const EdgeInsets.all(16),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Display Name',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _firstNameController,
              label: 'First Name',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'First name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _lastNameController,
              label: 'Last Name',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Last name is required';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Container(
      margin: const EdgeInsets.all(16),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Password',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _currentPasswordController,
              label: 'Current Password',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (value) {
                if (value?.isNotEmpty ?? false) {
                  if (value!.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _newPasswordController,
              label: 'New Password',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (value) {
                if (_currentPasswordController.text.isNotEmpty) {
                  if (value == null || value.isEmpty) {
                    return 'New password is required';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _confirmPasswordController,
              label: 'Confirm New Password',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (value) {
                if (_newPasswordController.text.isNotEmpty) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Leave password fields empty if you don\'t want to change it',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_showPassword,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.primary),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _showPassword = !_showPassword;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.primaryLight.withOpacity(0.2),
          ),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildSaveButton() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textLight,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: AppColors.textLight,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
