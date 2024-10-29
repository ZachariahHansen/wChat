import 'package:flutter/material.dart';
import 'package:wchat/data/models/user.dart';
import 'package:wchat/data/models/role.dart';
import 'package:wchat/ui/Home/manager_app_drawer.dart';
import 'package:wchat/services/api/user_api.dart';
import 'package:wchat/services/api/role_api.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _departmentsController = TextEditingController();
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
    _departmentsController.dispose();
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
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _showUserFormDialog({User? user}) async {
    // Controllers for form fields
    final firstNameController = TextEditingController(text: user?.firstName);
    final lastNameController = TextEditingController(text: user?.lastName);
    final emailController = TextEditingController(text: user?.email);
    final phoneController = TextEditingController(text: user?.phoneNumber);
    final hourlyRateController = TextEditingController(
      text: user?.hourlyRate.toString() ?? ''
    );
    _departmentsController.text = user?.departments.join(', ') ?? '';
    bool isManager = user?.isManager ?? false;
    
    // Find the role ID for the user's current role
    int? selectedRoleId;
    if (user != null) {
      final userRole = _roles.firstWhere(
        (role) => role.name == user.role,
        orElse: () => _roles.first,
      );
      selectedRoleId = userRole.id;
    } else {
      selectedRoleId = _roles.isNotEmpty ? _roles.first.id : null;
    }

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(user == null ? 'Create New User' : 'Edit User'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        hintText: 'Enter first name',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        hintText: 'Enter last name',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter email address',
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'Enter phone number',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: hourlyRateController,
                      decoration: const InputDecoration(
                        labelText: 'Hourly Rate',
                        hintText: 'Enter hourly rate',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _departmentsController,
                      decoration: const InputDecoration(
                        labelText: 'Departments',
                        hintText: 'Enter departments (comma-separated)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedRoleId,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                      ),
                      items: _roles.map((Role role) {
                        return DropdownMenuItem<int>(
                          value: role.id,
                          child: Text(role.name),
                        );
                      }).toList(),
                      onChanged: (int? newValue) {
                        setState(() {
                          selectedRoleId = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Is Manager'),
                      value: isManager,
                      onChanged: (bool? value) {
                        setState(() {
                          isManager = value ?? false;
                        });
                      },
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
                    if (firstNameController.text.isNotEmpty &&
                        lastNameController.text.isNotEmpty &&
                        emailController.text.isNotEmpty &&
                        selectedRoleId != null) {
                      try {
                        final userData = {
                          'first_name': firstNameController.text,
                          'last_name': lastNameController.text,
                          'email': emailController.text,
                          'phone_number': phoneController.text,
                          'hourly_rate': double.tryParse(hourlyRateController.text) ?? 0.0,
                          'role_id': selectedRoleId,
                          'departments': _departmentsController.text,
                          'is_manager': isManager,
                        };

                        if (user == null) {
                          await _userApi.createUser(userData);
                        } else {
                          await _userApi.updateUser(user.id, userData);
                        }
                        Navigator.of(context).pop();
                        await _fetchUsers();
                      } catch (e) {
                        _showErrorSnackBar(
                          'Failed to ${user == null ? 'create' : 'update'} user: $e'
                        );
                      }
                    }
                  },
                  child: Text(user == null ? 'Create' : 'Update'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
      ),
      drawer: const ManagerDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
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
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showUserFormDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('Create User'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12
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
                        return Card(
                          child: ListTile(
                            title: Text('${user.firstName} ${user.lastName}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.email),
                                Text('Role: ${user.role}'),
                                if (user.departments.isNotEmpty)
                                  Text('Departments: ${user.departments.join(", ")}'),
                                Text('Hourly Rate: \$${user.hourlyRate.toStringAsFixed(2)}'),
                                if (user.isManager)
                                  const Text('Manager', 
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue
                                    )
                                  ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showUserFormDialog(user: user),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete User'),
                                        content: Text(
                                          'Are you sure you want to delete ${user.firstName} ${user.lastName}?'
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => 
                                              Navigator.of(context).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => 
                                              Navigator.of(context).pop(true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
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
                                        _showErrorSnackBar(
                                          'Failed to delete user: $e'
                                        );
                                      }
                                    }
                                  },
                                  color: Colors.red,
                                ),
                              ],
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