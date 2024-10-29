import 'package:flutter/material.dart';

class ManagerDrawer extends StatelessWidget {
  const ManagerDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.indigo, // Different color to distinguish manager view
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'wChat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Manager Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/manager');
            },
          ),
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Departments'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/manager/departments');
            },
          ),
          ListTile(
            leading: const Icon(Icons.work),
            title: const Text('Roles'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/manager/roles');
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Shifts'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/manager/shifts');
            },
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Users'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/manager/users');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.arrow_back),
            title: const Text('Back to Employee View'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/home');
            },
          ),
        ],
      ),
    );
  }
}