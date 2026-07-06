import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF00D4FF),
    scaffoldBackgroundColor: Colors.black,
    cardColor: Colors.grey[900],
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00D4FF),
      secondary: Color(0xFF00F5FF),
      surface: Colors.black,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    textTheme: GoogleFonts.notoSansTextTheme(),
    useMaterial3: true,
  );

  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF00D4FF),
    scaffoldBackgroundColor: Colors.white,
    cardColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF00D4FF),
      secondary: Color(0xFF00F5FF),
      surface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Colors.black87),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
    textTheme: GoogleFonts.notoSansTextTheme(),
    useMaterial3: true,
  );
}
