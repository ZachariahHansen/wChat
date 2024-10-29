import 'package:flutter/material.dart';
import 'package:wchat/data/models/user.dart';
import 'package:wchat/data/models/department.dart';
import 'package:wchat/ui/Home/manager_app_drawer.dart';
import 'package:wchat/services/api/department_api.dart';
import 'package:wchat/services/api/user_api.dart';
import 'package:wchat/ui/Manager/Department/modify_departments_screen.dart'; 

class DepartmentScreen extends StatefulWidget {
  const DepartmentScreen({super.key});

  @override
  State<DepartmentScreen> createState() => _DepartmentScreenState();
}

class _DepartmentScreenState extends State<DepartmentScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DepartmentApi _departmentApi = DepartmentApi();
  final UserApi _userApi = UserApi();
  
  List<User> _users = [];
  List<User> _filteredUsers = [];
  List<Department> _departments = [];
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
      _fetchDepartments(),
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

  Future<void> _fetchDepartments() async {
    try {
      final departments = await _departmentApi.getAllDepartments();
      setState(() {
        _departments = departments;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load departments: $e');
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

  Future<void> _showAddDepartmentDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Department'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Department Name',
                    hintText: 'Enter department name',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter department description',
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
                    await _departmentApi.createDepartment(
                      nameController.text,
                      descriptionController.text,
                    );
                    Navigator.of(context).pop();
                    await _fetchDepartments();
                  } catch (e) {
                    _showErrorSnackBar('Failed to create department: $e');
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

  void _showAssignDepartmentDialog(User user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Assign Departments - ${user.firstName} ${user.lastName}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _departments.length,
              itemBuilder: (context, index) {
                final department = _departments[index];
                final isAssigned = user.departments.contains(department.name);

                return CheckboxListTile(
                  title: Text(department.name),
                  subtitle: Text(department.description),
                  value: isAssigned,
                  onChanged: (bool? value) async {
                    if (value != null) {
                      try {
                        if (value) {
                          await _departmentApi.assignUserToDepartment(user.id, department.id);
                        } else {
                          await _departmentApi.removeUserFromDepartment(user.id, department.id);
                        }
                        await _fetchUsers(); // Refresh the users list
                        Navigator.of(context).pop();
                      } catch (e) {
                        _showErrorSnackBar('Failed to update department assignment: $e');
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
        title: const Text('Department Management'),
      ),
      drawer: const ManagerDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Update the Row in the build method of DepartmentScreen
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    ElevatedButton.icon(
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DepartmentManagementScreen()),
        );
      },
      icon: const Icon(Icons.settings),
      label: const Text('Manage Departments'),
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
                        return Card(
                          child: ListTile(
                            title: Text('${user.firstName} ${user.lastName}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.email),
                                Text('Departments: ${user.departments.isEmpty ? 'None' : user.departments.join(", ")}'),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showAssignDepartmentDialog(user),
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
