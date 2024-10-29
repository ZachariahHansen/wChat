import 'package:flutter/material.dart';
import 'package:wchat/ui/Login/login_screen.dart';
import 'package:wchat/ui/Home/home_screen.dart';
import 'package:wchat/ui/Schedule/schedule_screen.dart';
import 'package:wchat/ui/Directory/directory_screen.dart';
import 'package:wchat/ui/Message/message_list_screen.dart';
import 'package:wchat/ui/Schedule/available_shift_screen.dart';
import 'package:wchat/ui/Profile/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:wchat/services/webSocket/web_socket_provider.dart';
import 'package:wchat/ui/Home/manager_home_screen.dart';
import 'package:wchat/ui/Manager/Department/department_screen.dart';
import 'package:wchat/ui/Manager/Roles/roles_screen.dart';
import 'package:wchat/ui/Manager/User/users_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WebSocketProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'wChat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: LoginScreen(),
      routes: {
        '/': (context) => HomeScreen(),
        '/home': (context) => HomeScreen(),
        '/schedule': (context) => ScheduleScreen(),
        '/directory': (context) => DirectoryScreen(),
        '/messages': (context) => MessageListScreen(),
        '/shifts/available': (context) => const ShiftPickupScreen(),
        '/manager': (context) => ManagerHomeScreen(),
        '/manager/departments': (context) => const DepartmentScreen(),
        '/manager/roles': (context) => const RoleScreen(),
        '/manager/users': (context) => const UserManagementScreen(),
        
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/profile') {
          final userId = settings.arguments as int;
          return MaterialPageRoute(
            builder: (context) => UserProfileScreen(userId: userId),
          );
        }
        return null;
      },
    );
  }
}
