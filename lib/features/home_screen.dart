import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

// Import Role-based Home Screens
import 'student_home.dart';
import 'lecturer_home.dart' as lecturer;

// In home_screen.dart, update the build method to pass toggleTheme to student/tutor homes
class HomeScreen extends StatelessWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const HomeScreen({super.key, required this.toggleTheme, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final userRole = auth.currentUser?.role ?? '';

    if (userRole == 'student') {
      return StudentHome(toggleTheme: toggleTheme, isDarkMode: isDarkMode);
    } else {
      return lecturer.LecturerHome(toggleTheme: toggleTheme, isDarkMode: isDarkMode);
    }
  }
}