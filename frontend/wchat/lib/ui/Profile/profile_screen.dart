import 'package:flutter/material.dart';
import 'package:wchat/data/models/user.dart';
import 'package:wchat/services/api/user_api.dart';
import 'package:wchat/ui/Message/conversation_screen.dart';

class UserProfileScreen extends StatelessWidget {
  final int userId;

  const UserProfileScreen({super.key, required this.userId});

  Future<User> _fetchProfile() async {
    UserApi userApi = UserApi();
    return await userApi.getUserProfile(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
      ),
      body: FutureBuilder<User>(
        future: _fetchProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_off, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No profile data found'),
                ],
              ),
            );
          }

          final profile = snapshot.data!;
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text(
                            '${profile.firstName[0]}${profile.lastName[0]}',
                            style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildInfoRow(
                        Icons.person,
                        'Name',
                        '${profile.firstName} ${profile.lastName}',
                      ),
                      _buildInfoRow(Icons.email, 'Email', profile.email),
                      _buildInfoRow(Icons.phone, 'Phone', profile.phoneNumber),
                      _buildInfoRow(Icons.work, 'Role', profile.role),
                      if (profile.departments.isNotEmpty)
                        _buildDepartmentsSection(profile.departments),
                      _buildInfoRow(
                        Icons.admin_panel_settings,
                        'Manager',
                        profile.isManager ? 'Yes' : 'No',
                      ),
                      _buildInfoRow(
                        Icons.attach_money,
                        'Hourly Rate',
                        '\$${profile.hourlyRate.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ConversationScreen(
                                  otherUserId: userId,
                                  otherUserName:
                                      '${profile.firstName} ${profile.lastName}',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.message),
                          label: const Text('Message User'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentsSection(List<String> departments) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.business, color: Colors.blue),
              SizedBox(width: 12),
              Text(
                'Departments',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: departments.map((department) {
                return Chip(
                  label: Text(department),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}