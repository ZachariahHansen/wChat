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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _userApi = UserApi();
    _fetchUsers();
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

  void _navigateToProfileScreen(User user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: user.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Directory'),
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: _fetchUsers,
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return ListTile(
                    title: Text(user.fullName),
                    onTap: () => _navigateToProfileScreen(user),
                  );
                },
              ),
      ),
    );
  }
}
