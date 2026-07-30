import 'package:flutter/material.dart';

class AppTheme {
  static const _lightFillColor = Colors.black;
  static const _darkFillColor = Colors.white;

  static final Color _lightFocusColor = Colors.black.withValues(alpha: 0.12);
  static final Color _darkFocusColor = Colors.white.withValues(alpha: 0.12);

  static ThemeData lightTheme = ThemeData(
    fontFamily: 'NotoSans',
    primaryColor: const Color(0xFF00D4FF),
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF00D4FF),
      secondary: Color(0xFF00F5FF),
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      surface: Colors.white,
      onSurface: Colors.black,
      error: Colors.red,
      onError: Colors.white,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: Colors.grey[200],
    textTheme: _textTheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.grey[200],
      iconTheme: const IconThemeData(color: Colors.black),
      titleTextStyle: _textTheme.titleLarge?.copyWith(color: Colors.black),
    ),
    iconTheme: const IconThemeData(color: Colors.black54),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00D4FF),
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    focusColor: _lightFocusColor,
  );

  static ThemeData darkTheme = ThemeData(
    fontFamily: 'NotoSans',
    primaryColor: const Color(0xFF00D4FF),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00D4FF),
      secondary: Color(0xFF00F5FF),
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      surface: Color(0xFF1E1E1E),
      onSurface: Colors.white,
      error: Colors.redAccent,
      onError: Colors.white,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: Colors.black,
    textTheme: _textTheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.black,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: _textTheme.titleLarge?.copyWith(color: Colors.white),
    ),
    iconTheme: const IconThemeData(color: Colors.white70),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF00D4FF),
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    focusColor: _darkFocusColor,
  );

  static const TextTheme _textTheme = TextTheme(
    displayLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 57),
    displayMedium: TextStyle(fontWeight: FontWeight.bold, fontSize: 45),
    displaySmall: TextStyle(fontWeight: FontWeight.bold, fontSize: 36),
    headlineLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
    headlineMedium: TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
    headlineSmall: TextStyle(fontWeight: FontWeight.w600, fontSize: 24),
    titleLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 22),
    titleMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
    titleSmall: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
    bodyLarge: TextStyle(fontWeight: FontWeight.normal, fontSize: 16),
    bodyMedium: TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
    bodySmall: TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
    labelLarge: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    labelMedium: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
    labelSmall: TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
  );
}
