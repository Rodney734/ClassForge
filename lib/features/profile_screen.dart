import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _isUploading = false;
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
      backgroundColor: Colors.transparent, // Keep scaffold transparent
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(isDesktop ? 40 : 20),
          child: FadeTransition(
            opacity: _animationController,
            child: Column(
              children: [
                // Header
                _buildHeader(isDarkMode, isDesktop),

                const SizedBox(height: 30),

                // Profile Picture Section
                _buildProfilePictureSection(user, isDarkMode, isDesktop),

                const SizedBox(height: 30),

                // User Info Section
                _buildUserInfoSection(user, isDarkMode),

                const SizedBox(height: 30),

                // Stats Section
                _buildStatsSection(user, isDarkMode),

                // Account Actions Section
                _buildAccountActionsSection(auth, isDarkMode),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode, bool isDesktop) {
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
                      ? NetworkImage(user.profilePicture!)
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
    return GlassmorphicContainer(
      width: double.infinity,
      height: 380, // Adjusted height
      borderRadius: 24,
      blur: 20,
      linearGradient: LinearGradient(
        colors: [
          (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.1),
          (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: 1,
      borderGradient: LinearGradient(
        colors: [
          (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.2),
          (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.2),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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

            const Divider(height: 24),

            // Bio
            _buildInfoRow(
              Icons.article_outlined,
              "Bio",
              user.bio?.isNotEmpty == true ? user.bio! : "No bio yet.",
              isDarkMode,
            ),
          ],
        ),
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
    return Container(
      // Using a standard container for better performance
      // The glass effect on small, static items is expensive
      width: double.infinity,
      height: 100, // Adjusted height
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00F5FF).withValues(alpha: 0.1),
            const Color(0xFF00F5FF).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          width: 1,
          color: const Color(0xFF00F5FF).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Expanded(
          //   child: _buildStatItem(
          //     stats['questions'].toString(),
          //     "Questions",
          //     Icons.help_outline,
          //     isDarkMode,
          //   ),
          // ),
          Container(
            width: 1,
            height: 40,
            color: isDarkMode ? Colors.white24 : Colors.black12,
          ),
          Expanded(
            child: _buildStatItem(
              "0",
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
              "0",
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
      // This Column is causing an overflow, needs to be wrapped or sized.
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

  Widget _buildAccountActionsSection(AuthService auth, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(top: 30),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.1),
              (isDarkMode ? Colors.white : Colors.black).withValues(
                alpha: 0.05,
              ),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            width: 1,
            color: (isDarkMode ? Colors.white : Colors.black).withValues(
              alpha: 0.2,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionItem(
                Icons.edit_outlined,
                "Edit Profile",
                "Update your name and bio",
                isDarkMode,
                onTap: () => _showEditProfileDialog(),
                destructiveColor: Colors.blue,
              ),
              const Divider(height: 24),
              _buildActionItem(
                Icons.settings_outlined,
                "Settings",
                "Appearance, account, and more",
                isDarkMode,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
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
        ),
      ),
    );
  }

  Widget _buildActionItem(
    IconData icon,
    String title,
    String subtitle,
    bool isDarkMode, {
    required VoidCallback onTap,
    Color? destructiveColor,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                (isDestructive
                        ? (destructiveColor ?? Colors.red)
                        : const Color(0xFF00F5FF))
                    .withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isDestructive
                ? (destructiveColor ?? Colors.red)
                : const Color(0xFF00F5FF),
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDestructive && destructiveColor == null
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
      // --- File Size Validation ---
      final int fileSize = await image.length(); // size in bytes
      const int maxSizeInBytes = 3 * 1024 * 1024; // 2 MB

      if (fileSize > maxSizeInBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Image is too large. Please select an image under 2MB.',
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      setState(() => _isUploading = true);

      try {
        final auth = Provider.of<AuthService>(context, listen: false);
        final imageBytes = await image.readAsBytes();
        await auth.updateProfilePicture(imageBytes);

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

  void _showEditProfileDialog() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    final nameController = TextEditingController(text: user.fullName);
    final bioController = TextEditingController(text: user.bio);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final isDarkMode =
            Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Edit Profile"),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: bioController,
                  decoration: const InputDecoration(
                    labelText: "Bio",
                    hintText: "Tell us a little about yourself",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  await auth.updateUserProfile(
                    fullName: nameController.text.trim(),
                    bio: bioController.text.trim(),
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Profile updated successfully!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }
}
