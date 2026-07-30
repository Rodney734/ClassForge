import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'lecturer_home.dart';
import 'login_screen.dart';
import 'student_home.dart';

/// A widget that listens to the authentication state and displays the
/// appropriate screen.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Use context.watch to listen for changes in AuthService.
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    // The authStateChanges stream in AuthService will notify this provider,
    // causing this widget to rebuild whenever the login state changes.

    if (user == null) {
      // If no user is logged in, show the login screen.
      return const LoginScreen();
    } else {
      // If a user is logged in, check their role to show the correct dashboard.
      switch (user.role) {
        case 'student':
          return const StudentHome();
        case 'lecturer':
          return const LecturerHome();
        default:
          // As a fallback, show a loading screen or an error page.
          return Scaffold(
            body: Center(child: const Text('Unknown user role.')),
          );
      }
    }
  }
}
