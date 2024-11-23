import 'package:flutter/material.dart';
import 'package:wchat/data/models/user.dart';
import 'package:wchat/data/models/role.dart';
import 'package:wchat/services/api/user_api.dart';
import 'package:wchat/data/app_theme.dart';

class CreateUserForm extends StatefulWidget {
  final User? user;
  final List<Role> roles;
  final Function onUserUpdated;

  const CreateUserForm({
    super.key,
    this.user,
    required this.roles,
    required this.onUserUpdated,
  });

  @override
  State<CreateUserForm> createState() => _CreateUserFormState();
}

class _CreateUserFormState extends State<CreateUserForm> {
  final UserApi _userApi = UserApi();
  final TextEditingController _departmentsController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _hourlyRateController = TextEditingController();
  
  bool _isManager = false;
  bool _isFullTime = true;
  int? _selectedRoleId;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final user = widget.user;
    if (user != null) {
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
      _emailController.text = user.email;
      _phoneController.text = user.phoneNumber;
      _hourlyRateController.text = user.hourlyRate.toString();
      _departmentsController.text = user.departments.join(', ');
      _isManager = user.isManager;
      _isFullTime = user.fullTime;
      
      final userRole = widget.roles.firstWhere(
        (role) => role.name == user.role,
        orElse: () => widget.roles.first,
      );
      _selectedRoleId = userRole.id;
    } else {
      _selectedRoleId = widget.roles.isNotEmpty ? widget.roles.first.id : null;
    }
  }

  @override
  void dispose() {
    _departmentsController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
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

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int? maxLines,
    Widget? prefix,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary),
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
        prefix: prefix,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primaryLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primaryLight.withOpacity(0.2)),
        ),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      title: Text(
        widget.user == null ? 'Create New User' : 'Edit User',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFormField(
                controller: _firstNameController,
                label: 'First Name',
                hint: 'Enter first name',
              ),
              const SizedBox(height: 16),
              _buildFormField(
                controller: _lastNameController,
                label: 'Last Name',
                hint: 'Enter last name',
              ),
              const SizedBox(height: 16),
              _buildFormField(
                controller: _emailController,
                label: 'Email',
                hint: 'Enter email address',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _buildFormField(
                controller: _phoneController,
                label: 'Phone Number',
                hint: 'Enter phone number',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildFormField(
                controller: _hourlyRateController,
                label: 'Hourly Rate',
                hint: 'Enter hourly rate',
                keyboardType: TextInputType.number,
                prefix: Text('\$ ', style: TextStyle(color: AppColors.textPrimary)),
              ),
              const SizedBox(height: 16),
              _buildFormField(
                controller: _departmentsController,
                label: 'Departments',
                hint: 'Enter departments (comma-separated)',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedRoleId,
                decoration: InputDecoration(
                  labelText: 'Role',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primaryLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primaryLight.withOpacity(0.2)),
                  ),
                ),
                items: widget.roles.map((Role role) {
                  return DropdownMenuItem<int>(
                    value: role.id,
                    child: Text(role.name),
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  setState(() {
                    _selectedRoleId = newValue;
                  });
                },
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primaryLight.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    CheckboxListTile(
                      title: Text(
                        'Is Manager',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      value: _isManager,
                      activeColor: AppColors.primary,
                      checkColor: AppColors.background,
                      onChanged: (bool? value) {
                        setState(() {
                          _isManager = value ?? false;
                        });
                      },
                    ),
                    Divider(height: 1, color: AppColors.primaryLight.withOpacity(0.2)),
                    CheckboxListTile(
                      title: Text(
                        'Full Time',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      value: _isFullTime,
                      activeColor: AppColors.primary,
                      checkColor: AppColors.background,
                      onChanged: (bool? value) {
                        setState(() {
                          _isFullTime = value ?? true;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_firstNameController.text.isNotEmpty &&
                _lastNameController.text.isNotEmpty &&
                _emailController.text.isNotEmpty &&
                _selectedRoleId != null) {
              try {
                final userData = {
                  'first_name': _firstNameController.text,
                  'last_name': _lastNameController.text,
                  'email': _emailController.text,
                  'phone_number': _phoneController.text,
                  'hourly_rate': double.tryParse(_hourlyRateController.text) ?? 0.0,
                  'role_id': _selectedRoleId,
                  'departments': _departmentsController.text,
                  'is_manager': _isManager,
                  'full_time': _isFullTime,
                };

                if (widget.user == null) {
                  await _userApi.createUser(userData);
                } else {
                  await _userApi.updateUser(widget.user!.id, userData);
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                widget.onUserUpdated();
              } catch (e) {
                _showErrorSnackBar(
                  'Failed to ${widget.user == null ? 'create' : 'update'} user: $e'
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(widget.user == null ? 'Create' : 'Update'),
        ),
      ],
      actionsPadding: const EdgeInsets.all(16),
    );
  }
}