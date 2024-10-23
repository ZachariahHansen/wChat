import 'package:flutter/material.dart';
import 'package:wchat/services/api/user_api.dart';
import 'package:wchat/ui/Home/app_drawer.dart';
import 'package:wchat/ui/Profile/profile_screen.dart';

class User {
  final int userId;
  final String firstName;
  final String lastName;

  User({required this.userId, required this.firstName, required this.lastName});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
    );
  }

  String get fullName => '$firstName $lastName';
}

class DirectoryScreen extends StatefulWidget {
  @override
  _DirectoryScreenState createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  late UserApi _userApi;
  List<User> _users = [];
  List<User> _filteredUsers = []; // Add this line
  bool _isLoading = false;

  // Add controller for search field
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userApi = UserApi();
    _fetchUsers();
    
    // Add listener to search controller
    _searchController.addListener(_filterUsers);
  }

  // Add dispose method to clean up controller
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Add filter method
  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        return user.fullName.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final usersJson = await _userApi.getAllUsers();
      final users = usersJson.map((json) => User.fromJson(json)).toList();
      users.sort((a, b) => a.fullName.compareTo(b.fullName));
      setState(() {
        _users = users;
        _filteredUsers = users; // Initialize filtered list
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load users: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Directory'),
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Add search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                // Add clear button when search has input
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterUsers();
                        },
                      )
                    : null,
              ),
            ),
          ),
          // Wrap ListView in Expanded
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchUsers,
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _filteredUsers.length, // Use filtered list
                      itemBuilder: (context, index) {
                        final user = _filteredUsers[index]; // Use filtered list
                        return ListTile(
                          title: Text(user.fullName),
                          onTap: () => UserProfileScreen(userId: user.userId,),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}