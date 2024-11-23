import 'package:flutter/material.dart';
import 'package:wchat/data/models/user.dart';
import 'package:wchat/data/models/role.dart';
import 'package:wchat/ui/Home/manager_app_drawer.dart';
import 'package:wchat/services/api/user_api.dart';
import 'package:wchat/services/api/role_api.dart';
import 'package:wchat/ui/Manager/User/create_user_form.dart';
import 'package:wchat/data/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final UserApi _userApi = UserApi();
  final RoleApi _roleApi = RoleApi();

  List<User> _users = [];
  List<User> _filteredUsers = [];
  List<Role> _roles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterUsers);
    _fetchInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        _userApi.getAllUsers(),
        _roleApi.getAllRoles(),
      ]);
      
      setState(() {
        _users = futures[0] as List<User>;
        _filteredUsers = _users;
        _roles = futures[1] as List<Role>;
        _isLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        final fullName = '${user.firstName} ${user.lastName}'.toLowerCase();
        final email = user.email.toLowerCase();
        final role = user.role.toLowerCase();
        final departments = user.departments.join(' ').toLowerCase();
        
        return fullName.contains(query) ||
               email.contains(query) ||
               role.contains(query) ||
               departments.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _userApi.getAllUsers();
      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load users: $e');
      setState(() => _isLoading = false);
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

  void _showUserFormDialog({User? user}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: CreateUserForm(
            user: user,
            roles: _roles,
            onUserUpdated: _fetchUsers,
          ),
        );
      },
    );
  }

  Widget _buildUserCard(User user) {
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  user.role,
                  AppColors.primary,
                ),
                if (user.isManager)
                  _buildInfoChip(
                    'Manager',
                    AppColors.secondary,
                  ),
                _buildInfoChip(
                  user.fullTime ? 'Full Time' : 'Part Time',
                  AppColors.primary,
                ),
                _buildInfoChip(
                  '\$${user.hourlyRate.toStringAsFixed(2)}/hr',
                  AppColors.secondary,
                ),
              ],
            ),
            if (user.departments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: user.departments.map((dept) => _buildInfoChip(
                  dept,
                  AppColors.primary,
                )).toList(),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.edit,
                color: AppColors.primary,
              ),
              onPressed: () => _showUserFormDialog(user: user),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _showDeleteConfirmationDialog(user),
              color: AppColors.error,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Text(
          'Delete User',
          style: TextStyle(
            color: AppColors.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete ${user.firstName} ${user.lastName}?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _userApi.deleteUser(user.id);
        await _fetchUsers();
      } catch (e) {
        _showErrorSnackBar('Failed to delete user: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
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
                          onPressed: () => _showUserFormDialog(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Create User'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _fetchInitialData,
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) => _buildUserCard(_filteredUsers[index]),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
