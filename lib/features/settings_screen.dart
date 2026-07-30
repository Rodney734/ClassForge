import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[200],
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader('Appearance', isDarkMode),
          _buildSettingsCard(
            isDarkMode,
            child: ListTile(
              leading: Icon(
                isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: const Color(0xFF00F5FF),
              ),
              title: Text(
                'Dark Mode',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              trailing: Switch(
                value: isDarkMode,
                onChanged: (value) => themeNotifier.value = value,
                activeTrackColor: const Color(
                  0xFF00F5FF,
                ).withValues(alpha: 0.5),
                activeThumbColor: const Color(0xFF00F5FF),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsCard(
            isDarkMode,
            child: ValueListenableBuilder<double>(
              valueListenable: fontScaleNotifier,
              builder: (context, fontScale, child) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.text_fields,
                          color: const Color(0xFF00F5FF),
                        ),
                        title: Text(
                          'Text Size',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        trailing: Text(
                          '${fontScale.toStringAsFixed(1)}x',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Slider.adaptive(
                        value: fontScale.clamp(0.8, 1.5),
                        min: 0.8,
                        max: 1.5,
                        divisions: 7,
                        activeColor: const Color(0xFF00F5FF),
                        onChanged: (value) async {
                          await saveFontScale(value);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'A-',
                              style: TextStyle(
                                color: isDarkMode
                                    ? Colors.white60
                                    : Colors.black54,
                              ),
                            ),
                            Text(
                              'A+',
                              style: TextStyle(
                                color: isDarkMode
                                    ? Colors.white60
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildSettingsCard(
            isDarkMode,
            child: ValueListenableBuilder<String?>(
              valueListenable: wallpaperNotifier,
              builder: (context, wallpaperPath, child) {
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.wallpaper_outlined,
                        color: Color(0xFF00F5FF),
                      ),
                      title: Text(
                        'Wallpaper',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        wallpaperPath == null
                            ? 'No wallpaper selected'
                            : 'Custom wallpaper active',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'Choose wallpaper',
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        color: const Color(0xFF00F5FF),
                        onPressed: _chooseWallpaper,
                      ),
                    ),
                    if (wallpaperPath != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SizedBox(
                          height: 120,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(wallpaperPath),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    if (wallpaperPath != null)
                      ListTile(
                        leading: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        title: const Text('Remove wallpaper'),
                        textColor: Colors.red,
                        iconColor: Colors.red,
                        onTap: removeWallpaper,
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('About', isDarkMode),
          _buildSettingsCard(
            isDarkMode,
            child: Column(
              children: [
                _buildInfoTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  isDarkMode: isDarkMode,
                  onTap: () async {
                    final url = Uri.parse(
                      'https://classforge.flycricket.io/privacy.html',
                    );
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
                const Divider(),
                _buildInfoTile(
                  icon: Icons.info_outline,
                  title: 'About ClassForge',
                  isDarkMode: isDarkMode,
                  onTap: () => _showAboutDialog(),
                ),
                const Divider(),
                _buildInfoTile(
                  icon: Icons.code,
                  title: 'Version',
                  subtitle: "1.0.0", // This can be loaded dynamically
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseWallpaper() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2560,
      maxHeight: 2560,
    );
    if (image == null) return;

    try {
      await saveWallpaper(image.path);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Wallpaper updated')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not set wallpaper: $error')),
      );
    }
  }

  Widget _buildSectionHeader(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: isDarkMode ? Colors.white54 : Colors.black54,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(bool isDarkMode, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool isDarkMode,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDarkMode ? Colors.white70 : Colors.black54),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: isDarkMode ? Colors.white54 : Colors.black54,
              ),
            )
          : null,
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: Colors.grey)
          : null,
      onTap: onTap,
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'ClassForge',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF00F5FF), Color(0xFF00D4FF)],
          ),
        ),
        child: const Icon(Icons.school, size: 32, color: Colors.black),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: const Text(
            'ClassForge is an education platform for students and lecturers.',
          ),
        ),
      ],
    );
  }
}
