import 'package:flutter/material.dart';
import 'package:wchat/data/models/user.dart';
import 'package:wchat/services/api/user_api.dart';

class UserProfileScreen extends StatelessWidget {
  final int userId;

  const UserProfileScreen({required this.userId});

  Future<User> _fetchProfile() async {
    UserApi userApi = UserApi();
    return await userApi.getUserProfile(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Profile'),
      ),
      body: FutureBuilder<User>(
        future: _fetchProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('No profile data found'));
          }

          final profile = snapshot.data!;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          child: Text(
                            '${profile.firstName[0]}${profile.lastName[0]}',
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(Icons.person, 'Name', '${profile.firstName} ${profile.lastName}'),
                      _buildInfoRow(Icons.email, 'Email', profile.email),
                      _buildInfoRow(Icons.phone, 'Phone', profile.phoneNumber),
                      _buildInfoRow(Icons.work, 'Role', profile.role),
                      if (profile.department != null)
                        _buildInfoRow(Icons.business, 'Department', profile.department!),
                      _buildInfoRow(Icons.admin_panel_settings, 'Manager', profile.isManager ? 'Yes' : 'No'),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // TODO: Implement navigation to message screen
                            print('Navigate to message screen for user: ${profile.id}');
                          },
                          child: const Text('Message User'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}