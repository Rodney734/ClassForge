import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

// Import Role-based Home Screens
import 'student_home.dart';
import 'lecturer_home.dart' as lecturer;

// In home_screen.dart, update the build method to pass toggleTheme to student/tutor homes
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final userRole = auth.currentUser?.role ?? '';

    if (userRole == 'student') {
      return const StudentHome();
    } else {
      return const lecturer.LecturerHome();
    }
  }
}
