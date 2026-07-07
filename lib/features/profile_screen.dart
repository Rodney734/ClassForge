import 'dart:io';
import 'package:flutter/material.dart';
import 'package:classforge/features/student_home.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const ProfileScreen({super.key, required this.toggleTheme});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _isUploading = false;
  bool _isUploadingBackground = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          image:
              user.backgroundImage != null && user.backgroundImage!.isNotEmpty
              ? DecorationImage(
                  image: MemoryImage(base64Decode(user.backgroundImage!)),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    (isDarkMode ? Colors.black : Colors.white).withOpacity(0.5),
                    BlendMode.darken,
                  ),
                )
              : null,
          color: isDarkMode ? Colors.black : Colors.grey[200],
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDarkMode
                  ? [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.85),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.85),
                      Colors.white.withValues(alpha: 0.95),
                    ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.all(isDesktop ? 40 : 20),
              child: FadeTransition(
                opacity: _animationController,
                child: Column(
                  children: [
                    // Header with theme toggle
                    _buildHeader(isDarkMode, isDesktop, widget.toggleTheme),

                    const SizedBox(height: 30),

                    // Profile Picture Section
                    _buildProfilePictureSection(user, isDarkMode, isDesktop),

                    const SizedBox(height: 30),

                    // User Info Section
                    _buildUserInfoSection(user, isDarkMode),

                    const SizedBox(height: 30),

                    // Stats Section
                    _buildStatsSection(user, isDarkMode),

                    const SizedBox(height: 30),

                    // Change Background Button
                    _buildChangeBackgroundButton(isDarkMode),

                    // Account Actions Section
                    _buildAccountActionsSection(auth, isDarkMode),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    bool isDarkMode,
    bool isDesktop,
    VoidCallback toggleTheme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "My Profile",
                style: TextStyle(
                  fontSize: isDesktop ? 36 : 32,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                "View your personal information",
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 14,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
        // Theme Toggle Switch
        Switch(
          value: isDarkMode,
          onChanged: (value) => toggleTheme(),
          activeTrackColor: const Color(0xFF00F5FF).withOpacity(0.5),
          activeColor: const Color(0xFF00F5FF),
          inactiveThumbColor: Colors.grey.shade400,
          inactiveTrackColor: Colors.grey.shade200,
        ),
      ],
    );
  }

  Widget _buildProfilePictureSection(user, bool isDarkMode, bool isDesktop) {
    return Center(
      child: GestureDetector(
        onTap: _isUploading ? null : () => _uploadProfilePicture(),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00F5FF).withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Main Avatar
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF00F5FF), width: 3),
                ),
                child: CircleAvatar(
                  radius: isDesktop ? 80 : 70,
                  backgroundColor: const Color(0xFF00F5FF),
                  backgroundImage:
                      user.profilePicture != null &&
                          user.profilePicture!.isNotEmpty
                      ? MemoryImage(base64Decode(user.profilePicture!))
                      : null,
                  child: user.profilePicture == null && !_isUploading
                      ? Text(
                          user.fullName[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: isDesktop ? 70 : 60,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        )
                      : null,
                ),
              ),

              // Upload overlay
              if (_isUploading)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                  child: CircleAvatar(
                    radius: isDesktop ? 80 : 70,
                    backgroundColor: Colors.transparent,
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),

              // Camera button
              if (!_isUploading)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F5FF),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDarkMode ? Colors.black : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoSection(user, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: (isDarkMode ? Colors.white : Colors.black).withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isDarkMode ? Colors.white : Colors.black).withValues(
            alpha: 0.15,
          ),
        ),
      ),
      child: Column(
        children: [
          // Full Name
          _buildInfoRow(
            Icons.person_outline,
            "Full Name",
            user.fullName,
            isDarkMode,
          ),

          const Divider(height: 24),

          // Email
          _buildInfoRow(
            Icons.email_outlined,
            "Email Address",
            user.email,
            isDarkMode,
          ),

          const Divider(height: 24),

          // Role & Level
          _buildInfoRow(
            Icons.school_outlined,
            "Role & Level",
            "${user.role.toUpperCase()} • Level ${user.level}",
            isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    bool isDarkMode,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF00F5FF).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF00F5FF)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(user, bool isDarkMode) {
    // These stats would come from your backend
    // For now, showing placeholder values
    final stats = {'questions': 0, 'answers': 0, 'streak': 0};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00F5FF).withValues(alpha: 0.1),
            const Color(0xFF00D4FF).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF00F5FF).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _buildStatItem(
              stats['questions'].toString(),
              "Questions",
              Icons.help_outline,
              isDarkMode,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: isDarkMode ? Colors.white24 : Colors.black12,
          ),
          Expanded(
            child: _buildStatItem(
              stats['answers'].toString(),
              "Answers",
              Icons.comment_outlined,
              isDarkMode,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: isDarkMode ? Colors.white24 : Colors.black12,
          ),
          Expanded(
            child: _buildStatItem(
              stats['streak'].toString(),
              "Streak",
              Icons.local_fire_department,
              isDarkMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    IconData icon,
    bool isDarkMode,
  ) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF00F5FF), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildChangeBackgroundButton(bool isDarkMode) {
    return GestureDetector(
      onTap: _isUploadingBackground ? null : _uploadBackgroundImage,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isUploadingBackground)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F5FF)),
                ),
              )
            else
              const Icon(Icons.image_outlined, color: Color(0xFF00F5FF)),
            const SizedBox(width: 12),
            Text(
              _isUploadingBackground
                  ? "Uploading..."
                  : "Change Background Image",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountActionsSection(AuthService auth, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isDarkMode ? Colors.white : Colors.black).withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isDarkMode ? Colors.white : Colors.black).withValues(
            alpha: 0.15,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildActionItem(
            Icons.help_outline,
            "Help & Support",
            "Get help or contact support",
            isDarkMode,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Help & Support coming soon!")),
              );
            },
          ),
          const Divider(height: 24),
          _buildActionItem(
            Icons.privacy_tip_outlined,
            "Privacy Policy",
            "Read our privacy policy",
            isDarkMode,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Privacy Policy coming soon!")),
              );
            },
          ),
          const Divider(height: 24),
          _buildActionItem(
            Icons.logout,
            "Sign Out",
            "Log out of your account",
            isDarkMode,
            isDestructive: true,
            onTap: () => _showSignOutDialog(auth),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
    IconData icon,
    String title,
    String subtitle,
    bool isDarkMode, {
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isDestructive ? Colors.red : const Color(0xFF00F5FF))
                .withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isDestructive ? Colors.red : const Color(0xFF00F5FF),
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDestructive
                ? Colors.red
                : (isDarkMode ? Colors.white : Colors.black87),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white60 : Colors.black54,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isDarkMode ? Colors.white60 : Colors.black54,
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _uploadProfilePicture() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image != null) {
      setState(() => _isUploading = true);

      try {
        final auth = Provider.of<AuthService>(context, listen: false);
        final imageBytes = await File(image.path).readAsBytes();
        final base64Image = base64Encode(imageBytes);
        await auth.updateProfilePicture(base64Image);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Profile picture updated successfully!"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error updating profile picture: $e"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _uploadBackgroundImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80, // Higher quality for background
      maxWidth: 1920, // Larger size for background
    );

    if (image != null) {
      setState(() => _isUploadingBackground = true);

      try {
        final auth = Provider.of<AuthService>(context, listen: false);
        final imageBytes = await File(image.path).readAsBytes();
        final base64Image = base64Encode(imageBytes);
        await auth.updateBackgroundImage(base64Image);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Background image updated successfully!"),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error updating background image: $e"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploadingBackground = false);
      }
    }
  }

  void _showSignOutDialog(AuthService auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sign Out"),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              auth.signOut();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Sign Out"),
          ),
        ],
      ),
    );
  }
}
