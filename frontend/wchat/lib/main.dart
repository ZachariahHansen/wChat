import 'package:flutter/material.dart';
import 'package:wchat/ui/Login/login_screen.dart';
import 'package:wchat/ui/Home/home_screen.dart';
import 'package:wchat/ui/Schedule/schedule_screen.dart';
import 'package:wchat/ui/Directory/directory_screen.dart';

void main() {
  runApp(const MyApp());
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
        '/schedule': (context) => ScheduleScreen(),
        '/directory': (context) => DirectoryScreen(),
      },
    );
  }
}
