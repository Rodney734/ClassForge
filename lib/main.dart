import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'features/auth/auth_gate.dart';
import 'features/login_screen.dart';
import 'features/register_screen.dart';
import 'features/multi_step_register_screen.dart';
import 'services/auth_service.dart';
import 'services/sync_manager.dart';
import 'utils/theme.dart';

// Global notifier to manage the app's theme (false = light, true = dark).
final themeNotifier = ValueNotifier<bool>(false);
final wallpaperNotifier = ValueNotifier<String?>(null);
final fontScaleNotifier = ValueNotifier<double>(1.0);

const _wallpaperPathKey = 'wallpaper_path';
const _fontScaleKey = 'font_scale';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  wallpaperNotifier.value = preferences.getString(_wallpaperPathKey);
  fontScaleNotifier.value = preferences.getDouble(_fontScaleKey) ?? 1.0;

  // Initialize Firebase with generated options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final syncManager = SyncManager();
  await syncManager.syncPendingActions();

  // Wrap the app in the provider here, AFTER Firebase has been initialized.
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (context) => AuthService())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listens to theme changes and rebuilds the MaterialApp.
    return ValueListenableBuilder<bool>(
      valueListenable: themeNotifier,
      builder: (context, isDarkMode, child) {
        return ValueListenableBuilder<String?>(
          valueListenable: wallpaperNotifier,
          builder: (context, wallpaperPath, child) {
            return ValueListenableBuilder<double>(
              valueListenable: fontScaleNotifier,
              builder: (context, fontScale, child) {
                return MaterialApp(
                  title: 'ClassForge',
                  theme: lightTheme,
                  darkTheme: darkTheme,
                  themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
                  debugShowCheckedModeBanner: false,
                  locale: const Locale('en'),
                  builder: (context, app) {
                    final mediaQuery = MediaQuery.of(context);
                    return MediaQuery(
                      data: mediaQuery.copyWith(
                        textScaler: TextScaler.linear(fontScale),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: isDarkMode
                                ? Colors.black
                                : Colors.grey[100]!,
                          ),
                          if (wallpaperPath != null)
                            Image.file(
                              File(wallpaperPath),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                            ),
                          ?app,
                        ],
                      ),
                    );
                  },
                  home: const AuthGate(),
                  routes: {
                    '/login': (context) => const LoginScreen(),
                    '/register': (context) => const MultiStepRegisterScreen(),
                    '/register-old': (context) => const RegisterScreen(),
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

Future<void> saveWallpaper(String sourcePath) async {
  final directory = await getApplicationDocumentsDirectory();
  final extension = sourcePath.contains('.')
      ? sourcePath.substring(sourcePath.lastIndexOf('.'))
      : '.jpg';
  final destination = File(
    '${directory.path}/classforge_wallpaper${extension.toLowerCase()}',
  );

  if (await destination.exists()) {
    await destination.delete();
  }
  await File(sourcePath).copy(destination.path);

  final preferences = await SharedPreferences.getInstance();
  await preferences.setString(_wallpaperPathKey, destination.path);
  wallpaperNotifier.value = destination.path;
}

Future<void> removeWallpaper() async {
  final path = wallpaperNotifier.value;
  if (path != null) {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  final preferences = await SharedPreferences.getInstance();
  await preferences.remove(_wallpaperPathKey);
  wallpaperNotifier.value = null;
}

Future<void> saveFontScale(double newScale) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setDouble(_fontScaleKey, newScale);
  fontScaleNotifier.value = newScale;
}
