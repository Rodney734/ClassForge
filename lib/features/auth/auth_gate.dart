import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '/features/login_screen.dart';
import '/features/student_home.dart';
import '/features/lecturer_home.dart';

/// A widget that listens to the authentication state and displays the
/// appropriate screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the AuthService to get the current user's state.
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    if (authService.isLoadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
          return const Scaffold(
            body: Center(child: Text("Unknown user role.")),
          );
      }
    }
  }
}
