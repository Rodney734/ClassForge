import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'features/login_screen.dart';
import 'features/home_screen.dart';
import 'services/auth_service.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Disable persistence to reduce noise and avoid IndexedDB interop crashes during debugging
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );

  await NotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = true;

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        // Add ThemeProvider if you want to use Provider for theme
      ],
      child: MaterialApp(
        title: 'ClassForge',
        debugShowCheckedModeBanner: false,
        theme: _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: AuthWrapper(toggleTheme: _toggleTheme, isDarkMode: _isDarkMode),
        // In your main.dart, add this to MaterialApp:
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              // Prevent keyboard from causing overflow
              viewInsets: EdgeInsets.zero,
            ),
            child: child!,
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const AuthWrapper({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);

    if (auth.currentUser == null) {
      return const LoginScreen();
    } else {
      return HomeScreen(toggleTheme: toggleTheme, isDarkMode: isDarkMode);
    }
  }
}
