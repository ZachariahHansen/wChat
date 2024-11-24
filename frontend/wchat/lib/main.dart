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
import 'package:wchat/ui/Profile/edit_profile_screen.dart';
import 'package:wchat/ui/Manager/Shift/shifts_screen.dart';
import 'package:wchat/ui/Availability/availability_screen.dart';
import 'package:wchat/ui/Manager/TimeOffRequests/time_off_requests_screen.dart';
import 'package:wchat/ui/Manager/Shift/generate_shifts_screen.dart';
import 'package:wchat/ui/ForgotPassword/forgot_password_screen.dart';
import 'package:wchat/ui/ForgotPassword/reset_password_screen.dart';

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
      title: 'WorkChat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: LoginScreen(),
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '');
        
        
        if (uri.path == '/reset-password') {
          final token = uri.queryParameters['token'];
          if (token == null) {
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Invalid reset link')),
              ),
            );
          }
          return MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(token: token),
          );
        }
        
        if (settings.name == '/profile') {
          final userId = settings.arguments as int;
          return MaterialPageRoute(
            builder: (context) => ProfileScreen(userId: userId),
          );
        }
        else if (settings.name == '/edit-profile') {
          final userId = settings.arguments as int;
          return MaterialPageRoute(
            builder: (context) => EditProfileScreen(userId: userId),
          );
        }

        
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => HomeScreen());
          case '/login':
            return MaterialPageRoute(builder: (_) => LoginScreen());
          case '/home':
            return MaterialPageRoute(builder: (_) => HomeScreen());
          case '/schedule':
            return MaterialPageRoute(builder: (_) => ScheduleScreen());
          case '/directory':
            return MaterialPageRoute(builder: (_) => DirectoryScreen());
          case '/messages':
            return MaterialPageRoute(builder: (_) => MessageListScreen());
          case '/shifts/available':
            return MaterialPageRoute(builder: (_) => const ShiftPickupScreen());
          case '/manager':
            return MaterialPageRoute(builder: (_) => ManagerHomeScreen());
          case '/manager/departments':
            return MaterialPageRoute(builder: (_) => const DepartmentScreen());
          case '/manager/roles':
            return MaterialPageRoute(builder: (_) => const RoleScreen());
          case '/manager/users':
            return MaterialPageRoute(builder: (_) => const UserManagementScreen());
          case '/manager/shifts':
            return MaterialPageRoute(builder: (_) => const ShiftsScreen());
          case '/manager/time_off':
            return MaterialPageRoute(builder: (_) => const TimeOffRequestsScreen());
          case '/manager/generate_shifts':
            return MaterialPageRoute(builder: (_) => const GenerateShiftsScreen());
          case '/availability':
            return MaterialPageRoute(builder: (_) => const AvailabilityForm());
          case '/forgot-password':
            return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Route not found')),
              ),
            );
        }
      },
    );
  }
}