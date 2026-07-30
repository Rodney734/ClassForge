import 'package:flutter/material.dart';

const Color _primaryColor = Color(0xFF00D4FF);
const Color _secondaryColor = Color(0xFF00F5FF);

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: _primaryColor,
  scaffoldBackgroundColor: Colors.grey[100],
  colorScheme: const ColorScheme.light(
    primary: _primaryColor,
    secondary: _secondaryColor,
    error: Colors.redAccent,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    iconTheme: IconThemeData(color: Colors.black87),
    titleTextStyle: TextStyle(
      color: Colors.black87,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  ),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: _primaryColor,
  scaffoldBackgroundColor: Colors.black,
  colorScheme: const ColorScheme.dark(
    primary: _primaryColor,
    secondary: _secondaryColor,
    error: Colors.red,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
  ),
);
