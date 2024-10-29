import 'package:flutter/material.dart';
import 'package:wchat/data/models/user.dart';
import 'package:wchat/data/models/role.dart';
import 'package:wchat/ui/Home/manager_app_drawer.dart';
import 'package:wchat/services/api/role_api.dart';
import 'package:wchat/services/api/user_api.dart';
import 'package:wchat/ui/Manager/Roles/modify_roles_screen.dart';

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
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _showAddRoleDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Role'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Role Name',
                    hintText: 'Enter role name',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter role description',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  try {
                    await _roleApi.createRole(
                      nameController.text,
                      descriptionController.text,
                    );
                    Navigator.of(context).pop();
                    await _fetchRoles();
                  } catch (e) {
                    _showErrorSnackBar('Failed to create role: $e');
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showAssignRoleDialog(User user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Assign Role - ${user.firstName} ${user.lastName}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _roles.length,
              itemBuilder: (context, index) {
                final role = _roles[index];
                final isAssigned = user.role == role.name;

                return RadioListTile(
                  title: Text(role.name),
                  subtitle: Text(role.description),
                  value: role.name,
                  groupValue: user.role,
                  onChanged: (String? value) async {
                    if (value != null) {
                      try {
                        await _userApi.updateUserRole(
                          user.id,
                          value,
                        );
                        await _fetchUsers(); // Refresh the users list
                        Navigator.of(context).pop();
                      } catch (e) {
                        _showErrorSnackBar('Failed to update role assignment: $e');
                      }
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
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
      ),
      drawer: const ManagerDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const RoleManagementScreen()),
                          );
                        },
                        icon: const Icon(Icons.settings),
                        label: const Text('Manage Roles'),
                      ),
                      SizedBox(
                        width: 300,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search Users',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _filterUsers();
                              },
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredUsers.length,
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index];
                        final userRole = _roles.firstWhere(
                          (role) => role.name == user.role,
                          orElse: () => Role(id: -1, name: 'None', description: ''),
                        );
                        
                        return Card(
                          child: ListTile(
                            title: Text('${user.firstName} ${user.lastName}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.email),
                                Text('Role: ${user.role.isEmpty ? 'None' : user.role}'),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showAssignRoleDialog(user),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
