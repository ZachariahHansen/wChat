import 'package:flutter/material.dart';
import 'package:wchat/data/models/user.dart';
import 'package:wchat/data/models/role.dart';
import 'package:wchat/ui/Home/manager_app_drawer.dart';
import 'package:wchat/services/api/role_api.dart';
import 'package:wchat/services/api/user_api.dart';
import 'package:wchat/ui/Manager/Roles/modify_roles_screen.dart';
import 'package:wchat/data/app_theme.dart';

class RoleScreen extends StatefulWidget {
  const RoleScreen({super.key});

  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  final TextEditingController _searchController = TextEditingController();
  final RoleApi _roleApi = RoleApi();
  final UserApi _userApi = UserApi();
  
  List<User> _users = [];
  List<User> _filteredUsers = [];
  List<Role> _roles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterUsers);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchUsers(),
      _fetchRoles(),
    ]);
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        final fullName = '${user.firstName} ${user.lastName}'.toLowerCase();
        final email = user.email.toLowerCase();
        return fullName.contains(query) || email.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchUsers() async {
    try {
      final users = await _userApi.getAllUsers();
      setState(() {
        _users = users;
        _filteredUsers = users;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load users: $e');
    }
  }

  Future<void> _fetchRoles() async {
    try {
      final roles = await _roleApi.getAllRoles();
      setState(() {
        _roles = roles;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load roles: $e');
    }
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

  void _showAssignRoleDialog(User user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Assign Role - ${user.firstName} ${user.lastName}',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _roles.length,
              itemBuilder: (context, index) {
                final role = _roles[index];
                final isAssigned = user.role == role.name;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primaryLight.withOpacity(0.2),
                    ),
                  ),
                  child: RadioListTile(
                    title: Text(
                      role.name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      role.description,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    value: role.name,
                    groupValue: user.role,
                    activeColor: AppColors.primary,
                    onChanged: (String? value) async {
                      if (value != null) {
                        try {
                          await _userApi.updateUserRole(user.id, value);
                          await _fetchUsers();
                          Navigator.of(context).pop();
                        } catch (e) {
                          _showErrorSnackBar('Failed to update role assignment: $e');
                        }
                      }
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Management'),
        elevation: 0,
      ),
      drawer: const ManagerDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.secondary.withOpacity(0.1),
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
            : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: 'Search Users',
                              labelStyle: TextStyle(color: AppColors.textSecondary),
                              prefixIcon: Icon(Icons.search, color: AppColors.primary),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear, color: AppColors.textSecondary),
                                      onPressed: () {
                                        _searchController.clear();
                                        _filterUsers();
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
                                borderSide: BorderSide(color: AppColors.primaryLight.withOpacity(0.2)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const RoleManagementScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.settings),
                          label: const Text('Manage Roles'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadInitialData,
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          final userRole = _roles.firstWhere(
                            (role) => role.name == user.role,
                            orElse: () => Role(id: -1, name: 'None', description: ''),
                          );
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: AppColors.primaryLight.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                '${user.firstName} ${user.lastName}',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    user.email,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: user.role.isEmpty
                                          ? AppColors.error.withOpacity(0.1)
                                          : AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      user.role.isEmpty ? 'No Role Assigned' : user.role,
                                      style: TextStyle(
                                        color: user.role.isEmpty
                                            ? AppColors.error
                                            : AppColors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color: AppColors.primary,
                                ),
                                onPressed: () => _showAssignRoleDialog(user),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
