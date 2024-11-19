
import 'package:flutter/material.dart';
import 'package:wchat/ui/ForgotPassword/forgot_password_screen.dart';
import 'package:wchat/ui/ForgotPassword/reset_password_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Extract the route path and query parameters
    final uri = Uri.parse(settings.name ?? '');
    
    switch (uri.path) {
      case '/forgot-password':
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
        
      case '/reset-password':
        // Get the token from query parameters
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

      // ... other routes ...

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Route not found')),
          ),
        );
    }
  }
}