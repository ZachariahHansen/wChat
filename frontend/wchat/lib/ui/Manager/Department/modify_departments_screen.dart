import 'package:flutter/material.dart';
import 'package:wchat/data/models/department.dart';
import 'package:wchat/ui/Home/manager_app_drawer.dart';
import 'package:wchat/services/api/department_api.dart';
import 'package:wchat/ui/Manager/Department/department_screen.dart';

class DepartmentManagementScreen extends StatefulWidget {
  const DepartmentManagementScreen({super.key});

  @override
  State<DepartmentManagementScreen> createState() =>
      _DepartmentManagementScreenState();
}

class _DepartmentManagementScreenState extends State<DepartmentManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DepartmentApi _departmentApi = DepartmentApi();

  List<Department> _departments = [];
  List<Department> _filteredDepartments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterDepartments);
    _fetchDepartments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterDepartments() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDepartments = _departments.where((department) {
        final name = department.name.toLowerCase();
        final description = department.description.toLowerCase();
        return name.contains(query) || description.contains(query);
      }).toList();
    });
  }

  Future<void> _fetchDepartments() async {
    setState(() => _isLoading = true);
    try {
      final departments = await _departmentApi.getAllDepartments();
      setState(() {
        _departments = departments;
        _filteredDepartments = departments;
        _isLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load departments: $e');
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

  Future<void> _showCreateDepartmentDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New Department'),
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

  Future<void> _showEditDepartmentDialog(Department department) async {
    final nameController = TextEditingController(text: department.name);
    final descriptionController =
        TextEditingController(text: department.description);

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Department'),
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
                    await _departmentApi.updateDepartment(
                      department.id,
                      name: nameController.text,
                      description: descriptionController.text,
                    );
                    Navigator.of(context).pop();
                    await _fetchDepartments();
                  } catch (e) {
                    _showErrorSnackBar('Failed to update department: $e');
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteConfirmationDialog(Department department) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Department'),
          content: Text('Are you sure you want to delete ${department.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _departmentApi.deleteDepartment(department.id);
                  Navigator.of(context).pop();
                  await _fetchDepartments();
                } catch (e) {
                  _showErrorSnackBar('Failed to delete department: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
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
        title: const Text('Manage Departments'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DepartmentScreen()),
          ),
        ),
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
                              labelText: 'Search Departments',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterDepartments();
                                },
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _showCreateDepartmentDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Create Department'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _filteredDepartments.length,
                      itemBuilder: (context, index) {
                        final department = _filteredDepartments[index];
                        return Card(
                          child: ListTile(
                            title: Text(department.name),
                            subtitle: Text(department.description),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () =>
                                      _showEditDepartmentDialog(department),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () =>
                                      _showDeleteConfirmationDialog(department),
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