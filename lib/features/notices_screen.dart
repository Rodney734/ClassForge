import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';

class NoticesScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const NoticesScreen({super.key, this.onBack});

  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
    final isLecturer = user?.role == "lecturer";

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Glass Morphism AppBar
            _buildGlassAppBar(isDarkMode, isLecturer),

            // Notices List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notices')
                    .where('level', isEqualTo: user?.level ?? 4)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF00F5FF),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    debugPrint("❌ Firestore Error: ${snapshot.error}");
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 60,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Error loading notices",
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final notices = snapshot.data?.docs ?? [];

                  if (notices.isEmpty) {
                    return _buildEmptyState(isDarkMode);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: notices.length,
                    itemBuilder: (context, index) {
                      final notice =
                          notices[index].data() as Map<String, dynamic>;
                      return FadeTransition(
                        opacity: _animationController,
                        child: SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: const Offset(0, 0.1),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: _animationController,
                                  curve: Interval(
                                    index * 0.1,
                                    1.0,
                                    curve: Curves.easeOut,
                                  ),
                                ),
                              ),
                          child: _buildNoticeCard(
                            notice,
                            isDarkMode,
                            isLecturer,
                            notices[index].id,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // FAB only for lecturers
      floatingActionButton: isLecturer
          ? FloatingActionButton.extended(
              onPressed: () => _showPostNoticeModal(context, user!),
              backgroundColor: const Color(0xFF00F5FF),
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text("New Notice"),
              elevation: 8,
            )
          : null,
    );
  }

  Widget _buildGlassAppBar(bool isDarkMode, bool isLecturer) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.12),
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: (isDarkMode ? Colors.white : Colors.black).withValues(
            alpha: 0.15,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (widget.onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: widget.onBack,
            ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00F5FF), Color(0xFF00D4FF)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.notifications_active,
              color: Colors.black,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Announcements",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  isLecturer
                      ? "Share updates with your students"
                      : "Stay informed with latest updates",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          if (isLecturer)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00F5FF), Color(0xFF00D4FF)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "Lecturer",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoticeCard(
    Map<String, dynamic> notice,
    bool isDarkMode,
    bool isLecturer,
    String docId,
  ) {
    final hasImage =
        notice['imageUrl'] != null && notice['imageUrl'].toString().isNotEmpty;
    final timestamp =
        (notice['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final timeAgo = _getTimeAgo(DateTime.now().difference(timestamp));
    final isPinned = notice['isPinned'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.08),
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPinned
              ? const Color(0xFF00F5FF).withValues(alpha: 0.4)
              : (isDarkMode ? Colors.white : Colors.black).withValues(
                  alpha: 0.1,
                ),
        ),
        boxShadow: [
          BoxShadow(
            color: isPinned
                ? const Color(0xFF00F5FF).withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => _showNoticeDetails(context, notice, isDarkMode),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                Stack(
                  children: [
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(notice['imageUrl']),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            (isDarkMode ? Colors.black : Colors.black)
                                .withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    if (isPinned)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00F5FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.push_pin,
                                size: 14,
                                color: Colors.black,
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Pinned",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF00F5FF),
                          child: Text(
                            (notice['postedBy'] as String?)?.isNotEmpty == true
                                ? (notice['postedBy'] as String)[0]
                                      .toUpperCase()
                                : "L",
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notice['postedBy'] ?? "Lecturer",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDarkMode
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF00F5FF,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(
                                0xFF00F5FF,
                              ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            "Level ${notice['level']}",
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF00F5FF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (notice['title'] != null &&
                        notice['title'].toString().isNotEmpty)
                      Text(
                        notice['title'],
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    if (notice['body'] != null &&
                        notice['body'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          notice['body'],
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                            height: 1.6,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (isLecturer) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                _showDeleteConfirmDialog(context, docId),
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red.withValues(alpha: 0.7),
                            ),
                            label: Text(
                              "Delete",
                              style: TextStyle(
                                color: Colors.red.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNoticeDetails(
    BuildContext context,
    Map<String, dynamic> notice,
    bool isDarkMode,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(
              color: (isDarkMode ? Colors.white : Colors.black).withValues(
                alpha: 0.1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Top handle bar for the modal
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDarkMode ? Colors.white : Colors.black).withValues(
                    alpha: 0.2,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (notice['imageUrl'] != null &&
                          notice['imageUrl'].toString().isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            notice['imageUrl'],
                            width: double.infinity,
                            fit: BoxFit
                                .contain, // Show full image without clipping
                          ),
                        ),
                      const SizedBox(height: 24),
                      Text(
                        notice['title'] ?? 'Announcement',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        notice['body'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Divider(),
                      const SizedBox(height: 12),
                      Text(
                        "Posted by ${notice['postedBy']} • Level ${notice['level']}",
                        style: TextStyle(
                          color: isDarkMode ? Colors.white38 : Colors.black38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00F5FF).withValues(alpha: 0.1),
                  const Color(0xFF00D4FF).withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF00F5FF).withValues(alpha: 0.2),
              ),
            ),
            child: Icon(
              Icons.inbox,
              size: 80,
              color: isDarkMode ? Colors.white24 : Colors.black26,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No Announcements Yet",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Check back later for updates",
            style: TextStyle(
              color: isDarkMode ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  void _showPostNoticeModal(BuildContext context, dynamic user) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String? imageUrl;
    bool isUploading = false;
    bool isPinned = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;

          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDarkMode
                    ? [Colors.grey[900]!, Colors.grey[800]!]
                    : [Colors.white, Colors.grey[50]!],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              border: Border(
                top: BorderSide(
                  color: (isDarkMode ? Colors.white : Colors.black).withValues(
                    alpha: 0.1,
                  ),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Handle bar
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: (isDarkMode ? Colors.white : Colors.black)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00F5FF),
                                    Color(0xFF00D4FF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.post_add,
                                color: Colors.black,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                "Create New Announcement",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Title Input
                        _buildGlassInput(
                          controller: titleController,
                          hintText: "Announcement Title",
                          icon: Icons.title,
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(height: 16),
                        // Body Input
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                (isDarkMode ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.06),
                                (isDarkMode ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.02),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (isDarkMode ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.1),
                            ),
                          ),
                          child: TextField(
                            controller: bodyController,
                            maxLines: 6,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: "Write your announcement here...",
                              hintStyle: TextStyle(
                                color: isDarkMode
                                    ? Colors.white54
                                    : Colors.black54,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Image Upload
                        _buildImageUploadButton(
                          isDarkMode: isDarkMode,
                          isUploading: isUploading,
                          imageUrl: imageUrl,
                          onTap: () async {
                            setState(() => isUploading = true);
                            try {
                              final picker = ImagePicker();
                              final XFile? pickedFile = await picker.pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 1024,
                                maxHeight: 1024,
                                imageQuality: 70,
                              );
                              if (pickedFile != null) {
                                final file = File(pickedFile.path);
                                final ref = FirebaseStorage.instance
                                    .ref()
                                    .child('notices/level_${user.level}')
                                    .child(
                                      '${DateTime.now().millisecondsSinceEpoch}.jpg',
                                    );

                                final UploadTask uploadTask = ref.putFile(
                                  file,
                                  SettableMetadata(contentType: 'image/jpeg'),
                                );

                                final TaskSnapshot snapshot = await uploadTask;
                                imageUrl = await snapshot.ref.getDownloadURL();

                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Image uploaded successfully!',
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error uploading image: $e'),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => isUploading = false);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        // Pin toggle
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                (isDarkMode ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.06),
                                (isDarkMode ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.02),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(
                                0xFF00F5FF,
                              ).withValues(alpha: 0.2),
                            ),
                          ),
                          child: SwitchListTile(
                            value: isPinned,
                            onChanged: (value) =>
                                setState(() => isPinned = value),
                            title: const Text(
                              "Pin this announcement",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              "Pinned notices appear at the top",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.white54
                                    : Colors.black54,
                              ),
                            ),
                            activeThumbColor: const Color(0xFF00F5FF),
                            activeTrackColor: const Color(
                              0xFF00F5FF,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: (isDarkMode ? Colors.white : Colors.black)
                                .withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (isDarkMode ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.1),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: Text(
                                    "Cancel",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00F5FF), Color(0xFF00D4FF)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF00F5FF,
                                ).withValues(alpha: 0.3),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap:
                                  isUploading ||
                                      titleController.text.isEmpty ||
                                      bodyController.text.isEmpty
                                  ? null
                                  : () async {
                                      try {
                                        await FirebaseFirestore.instance
                                            .collection('notices')
                                            .add({
                                              'title': titleController.text
                                                  .trim(),
                                              'body': bodyController.text
                                                  .trim(),
                                              'lecturerId': user.uid,
                                              'postedBy': user.fullName,
                                              'level': user.level,
                                              'imageUrl': imageUrl,
                                              'isPinned': isPinned,
                                              'timestamp':
                                                  FieldValue.serverTimestamp(),
                                            });
                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Announcement posted successfully!',
                                              ),
                                              backgroundColor: Colors.green,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: Text(
                                    isUploading ? "Uploading..." : "Publish",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
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
    );
  }

  Widget _buildGlassInput({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required bool isDarkMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.06),
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDarkMode ? Colors.white : Colors.black).withValues(
            alpha: 0.1,
          ),
        ),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: isDarkMode ? Colors.white54 : Colors.black54,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF00F5FF), size: 22),
        ),
      ),
    );
  }

  Widget _buildImageUploadButton({
    required bool isDarkMode,
    required bool isUploading,
    required String? imageUrl,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.06),
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: imageUrl != null
              ? Colors.green.withValues(alpha: 0.5)
              : const Color(0xFF00F5FF).withValues(alpha: 0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isUploading ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isUploading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF00F5FF),
                      ),
                    ),
                  )
                else
                  Icon(
                    imageUrl != null
                        ? Icons.check_circle
                        : Icons.image_outlined,
                    color: imageUrl != null
                        ? Colors.green
                        : const Color(0xFF00F5FF),
                    size: 24,
                  ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      imageUrl != null ? "Image attached ✓" : "Attach an image",
                      style: TextStyle(
                        color: imageUrl != null
                            ? Colors.green
                            : const Color(0xFF00F5FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      imageUrl != null ? "Tap to change" : "(Optional)",
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Announcement'),
        content: const Text(
          'Are you sure you want to delete this announcement? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('notices')
                  .doc(docId)
                  .delete();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Announcement deleted'),
                    backgroundColor: Colors.grey,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(Duration difference) {
    if (difference.inSeconds < 60) {
      return "just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}h ago";
    } else if (difference.inDays < 7) {
      return "${difference.inDays}d ago";
    } else {
      return "${(difference.inDays / 7).floor()}w ago";
    }
  }
}
