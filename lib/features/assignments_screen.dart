import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';

class AssignmentsScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const AssignmentsScreen({super.key, this.onBack});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen>
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
    final user = Provider.of<AuthService>(context).currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isLecturer = user?.role == "lecturer";

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const NetworkImage(
              "https://images.pexels.com/photos/256468/pexels-photo-256468.jpeg?auto=compress&cs=tinysrgb&w=1600",
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              isDarkMode
                  ? Colors.black.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.3),
              BlendMode.darken,
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDarkMode
                  ? [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.9),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.85),
                      Colors.white.withValues(alpha: 0.95),
                    ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Glass Morphism AppBar
                _buildGlassAppBar(isDarkMode, isLecturer),

                // Assignments List
                Expanded(
                  child: isLecturer
                      ? _buildLecturerView(isDarkMode)
                      : _buildStudentView(isDarkMode),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: isLecturer
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateAssignmentModal(context),
              backgroundColor: const Color(0xFF00F5FF),
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text("New Assignment"),
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
            child: const Icon(Icons.assignment, color: Colors.black, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Assignment",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  isLecturer
                      ? "Manage and grade assignment"
                      : "View and submit assignments",
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

  Widget _buildStudentView(bool isDarkMode) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('assignment')
          .where('level', isEqualTo: user.level)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F5FF)),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint("❌ Firestore Error (Student View): ${snapshot.error}");
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  "Error loading assignments",
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          );
        }

        final assignments = snapshot.data?.docs ?? [];

        if (assignments.isEmpty) {
          return _buildEmptyState(isDarkMode, isStudent: true);
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: assignments.length,
          itemBuilder: (context, index) {
            final doc = assignments[index];
            final data = doc.data() as Map<String, dynamic>;
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
                child: _buildStudentAssignmentCard(data, doc.id, isDarkMode),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLecturerView(bool isDarkMode) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('assignments')
          .where('lecturerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00F5FF)),
            ),
          );
        }

        if (snapshot.hasError) {
          debugPrint("❌ Firestore Error (Lecturer View): ${snapshot.error}");
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  "Error loading assignments",
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          );
        }

        final assignments = snapshot.data?.docs ?? [];

        if (assignments.isEmpty) {
          return _buildEmptyState(isDarkMode, isStudent: false);
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: assignments.length,
          itemBuilder: (context, index) {
            final doc = assignments[index];
            final data = doc.data() as Map<String, dynamic>;
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
                child: _buildLecturerAssignmentCard(data, doc.id, isDarkMode),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStudentAssignmentCard(
    Map<String, dynamic> data,
    String docId,
    bool isDarkMode,
  ) {
    final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
    final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now());
    final fileUrl = data['fileUrl'] as String?;
    final hasSubmitted = data['submitted'] != null && data['submitted'] == true;

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
          color: hasSubmitted
              ? Colors.green.withValues(alpha: 0.4)
              : isOverdue
              ? Colors.red.withValues(alpha: 0.4)
              : (isDarkMode ? Colors.white : Colors.black).withValues(
                  alpha: 0.1,
                ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hasSubmitted
                        ? Colors.green.withValues(alpha: 0.2)
                        : isOverdue
                        ? Colors.red.withValues(alpha: 0.2)
                        : const Color(0xFF00F5FF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    hasSubmitted ? Icons.check_circle : Icons.assignment,
                    color: hasSubmitted
                        ? Colors.green
                        : isOverdue
                        ? Colors.red
                        : const Color(0xFF00F5FF),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['title'] ?? 'Untitled',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['description'] ?? 'No description',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasSubmitted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "Submitted",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: isDarkMode ? Colors.white54 : Colors.black54,
                ),
                const SizedBox(width: 6),
                Text(
                  dueDate != null
                      ? "Due: ${_formatDate(dueDate)}"
                      : "No due date",
                  style: TextStyle(
                    fontSize: 12,
                    color: isOverdue
                        ? Colors.red
                        : (isDarkMode ? Colors.white70 : Colors.black54),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.school,
                  size: 14,
                  color: isDarkMode ? Colors.white54 : Colors.black54,
                ),
                const SizedBox(width: 6),
                Text(
                  "Level ${data['level']}",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (fileUrl != null)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF00F5FF).withValues(alpha: 0.15),
                            const Color(0xFF00D4FF).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF00F5FF).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _downloadFile(
                            fileUrl,
                            data['fileName'] ?? 'assignment.pdf',
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    data['fileName'] ?? 'Assignment.pdf',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: const Color(0xFF00F5FF),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(
                                  Icons.download,
                                  color: Color(0xFF00F5FF),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!hasSubmitted) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00F5FF), Color(0xFF00D4FF)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _submitAssignment(context, docId),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.upload_file,
                                  color: Colors.black,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  "Submit",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLecturerAssignmentCard(
    Map<String, dynamic> data,
    String docId,
    bool isDarkMode,
  ) {
    final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
    final submissionCount = data['submissionCount'] ?? 0;

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
          color: (isDarkMode ? Colors.white : Colors.black).withValues(
            alpha: 0.1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F5FF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.assignment,
                    color: Color(0xFF00F5FF),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['title'] ?? 'Untitled',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        data['description'] ?? 'No description',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
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
                    color: submissionCount > 0
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$submissionCount submitted",
                    style: TextStyle(
                      fontSize: 10,
                      color: submissionCount > 0 ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: isDarkMode ? Colors.white54 : Colors.black54,
                ),
                const SizedBox(width: 6),
                Text(
                  dueDate != null
                      ? "Due: ${_formatDate(dueDate)}"
                      : "No due date",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.school,
                  size: 14,
                  color: isDarkMode ? Colors.white54 : Colors.black54,
                ),
                const SizedBox(width: 6),
                Text(
                  "Level ${data['level']}",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (data['fileUrl'] != null)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF00F5FF).withValues(alpha: 0.15),
                            const Color(0xFF00D4FF).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF00F5FF).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _downloadFile(
                            data['fileUrl'],
                            data['fileName'] ?? 'assignment.pdf',
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.red,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    data['fileName'] ?? 'Assignment.pdf',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: const Color(0xFF00F5FF),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(
                                  Icons.download,
                                  color: Color(0xFF00F5FF),
                                  size: 16,
                                ),
                              ],
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _viewSubmissions(context, docId),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.visibility,
                                color: Colors.black,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                "View Submissions",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode, {required bool isStudent}) {
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
              Icons.assignment_outlined,
              size: 80,
              color: isDarkMode ? Colors.white24 : Colors.black26,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isStudent ? "No Assignments Yet" : "No Assignments Created",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isStudent
                ? "Check back later for new assignments"
                : "Create your first assignment using the + button",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDarkMode ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateAssignmentModal(BuildContext context) {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime? dueDate;
    String? fileUrl;
    String? fileName;
    bool isUploading = false;

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
                                Icons.add_task,
                                color: Colors.black,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                "Create New Assignment",
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
                          hintText: "Assignment Title",
                          icon: Icons.title,
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(height: 16),
                        // Description Input
                        _buildGlassInput(
                          controller: descriptionController,
                          hintText: "Description",
                          icon: Icons.description,
                          isDarkMode: isDarkMode,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 16),
                        // Due Date Picker
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
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(
                                    const Duration(days: 7),
                                  ),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => dueDate = picked);
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      color: const Color(0xFF00F5FF),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      dueDate != null
                                          ? "Due: ${_formatDate(dueDate!)}"
                                          : "Set Due Date",
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: dueDate != null
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.arrow_forward,
                                      color: const Color(0xFF00F5FF),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // File Upload
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
                              color: fileUrl != null
                                  ? Colors.green.withValues(alpha: 0.5)
                                  : const Color(
                                      0xFF00F5FF,
                                    ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isUploading
                                  ? null
                                  : () async {
                                      setState(() => isUploading = true);
                                      try {
                                        final user = Provider.of<AuthService>(
                                          context,
                                          listen: false,
                                        ).currentUser;
                                        final result = await FilePicker.platform
                                            .pickFiles(
                                              type: FileType.custom,
                                              allowedExtensions: [
                                                'pdf',
                                                'doc',
                                                'docx',
                                              ],
                                            );
                                        if (result != null &&
                                            result.files.isNotEmpty) {
                                          final file = File(
                                            result.files.single.path!,
                                          );
                                          final ref = FirebaseStorage.instance
                                              .ref()
                                              .child(
                                                'assignments/level_${user?.level}',
                                              )
                                              .child(
                                                '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}',
                                              );

                                          await ref.putFile(file);
                                          fileUrl = await ref.getDownloadURL();
                                          fileName = result.files.single.name;
                                        }
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      } finally {
                                        setState(() => isUploading = false);
                                      }
                                    },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    if (isUploading)
                                      const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Color(0xFF00F5FF),
                                              ),
                                        ),
                                      )
                                    else
                                      Icon(
                                        fileUrl != null
                                            ? Icons.check_circle
                                            : Icons.attach_file,
                                        color: fileUrl != null
                                            ? Colors.green
                                            : const Color(0xFF00F5FF),
                                        size: 24,
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fileUrl != null
                                                ? "File attached ✓"
                                                : "Attach assignment file",
                                            style: TextStyle(
                                              color: fileUrl != null
                                                  ? Colors.green
                                                  : const Color(0xFF00F5FF),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            fileUrl != null
                                                ? fileName ?? "File attached"
                                                : "(PDF, DOC, DOCX)",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDarkMode
                                                  ? Colors.white54
                                                  : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                              child: const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: Text(
                                    "Cancel",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
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
                                color: Color(0xFF00F5FF).withValues(alpha: 0.3),
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
                                      fileUrl == null ||
                                      dueDate == null
                                  ? null
                                  : () async {
                                      await FirebaseFirestore.instance
                                          .collection('assignments')
                                          .add({
                                            'title': titleController.text
                                                .trim(),
                                            'description': descriptionController
                                                .text
                                                .trim(),
                                            'dueDate': Timestamp.fromDate(
                                              dueDate!,
                                            ),
                                            'fileUrl': fileUrl,
                                            'fileName': fileName,
                                            'level': user?.level,
                                            'lecturerId': user?.uid,
                                            'lecturerName': user?.fullName,
                                            'submissionCount': 0,
                                            'createdAt':
                                                FieldValue.serverTimestamp(),
                                          });
                                      if (mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Assignment created successfully!',
                                            ),
                                            backgroundColor: Colors.green,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                              borderRadius: BorderRadius.circular(16),
                              child: const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: Text(
                                    "Create Assignment",
                                    style: TextStyle(
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
    int maxLines = 1,
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
        maxLines: maxLines,
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

  Future<void> _submitAssignment(
    BuildContext context,
    String assignmentId,
  ) async {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result == null) return;

      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;

      // Upload submission
      final ref = FirebaseStorage.instance
          .ref()
          .child('submissions/$assignmentId/${user?.uid}')
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      // Save submission
      await FirebaseFirestore.instance
          .collection('assignments')
          .doc(assignmentId)
          .collection('submissions')
          .add({
            'studentId': user?.uid,
            'studentName': user?.fullName,
            'fileUrl': url,
            'fileName': fileName,
            'submittedAt': FieldValue.serverTimestamp(),
            'grade': null,
            'feedback': null,
            'isGraded': false,
          });

      // Update submission count
      await FirebaseFirestore.instance
          .collection('assignments')
          .doc(assignmentId)
          .update({
            'submissionCount': FieldValue.increment(1),
            'submitted': true,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment submitted successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error submitting: $e')));
      }
    }
  }

  void _viewSubmissions(BuildContext context, String assignmentId) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [Colors.grey[900]!, Colors.grey[800]!]
                : [Colors.white, Colors.grey[50]!],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(
            top: BorderSide(
              color: (isDarkMode ? Colors.white : Colors.black).withValues(
                alpha: 0.1,
              ),
            ),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDarkMode ? Colors.white : Colors.black).withValues(
                    alpha: 0.2,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00F5FF), Color(0xFF00D4FF)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.people,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      "Submissions",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text("Close"),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('assignments')
                    .doc(assignmentId)
                    .collection('submissions')
                    .orderBy('submittedAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final submissions = snapshot.data?.docs ?? [];

                  if (submissions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 60, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            "No submissions yet",
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white54
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: submissions.length,
                    itemBuilder: (context, index) {
                      final data =
                          submissions[index].data() as Map<String, dynamic>;
                      final isGraded = data['isGraded'] ?? false;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
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
                            color: isGraded
                                ? Colors.green.withValues(alpha: 0.3)
                                : (isDarkMode ? Colors.white : Colors.black)
                                      .withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(
                                    0xFF00F5FF,
                                  ).withValues(alpha: 0.2),
                                  child: Text(
                                    (data['studentName'] ?? 'S')[0]
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF00F5FF),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['studentName'] ?? 'Unknown',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        _formatTime(
                                          (data['submittedAt'] as Timestamp?)
                                              ?.toDate(),
                                        ),
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
                                if (isGraded)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "Graded: ${data['grade']}%",
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(
                                            0xFF00F5FF,
                                          ).withValues(alpha: 0.15),
                                          const Color(
                                            0xFF00D4FF,
                                          ).withValues(alpha: 0.05),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF00F5FF,
                                        ).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _downloadFile(
                                          data['fileUrl'],
                                          data['fileName'],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.picture_as_pdf,
                                                color: Colors.red,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  data['fileName'] ??
                                                      'Submission.pdf',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: const Color(
                                                      0xFF00F5FF,
                                                    ),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const Icon(
                                                Icons.download,
                                                color: Color(0xFF00F5FF),
                                                size: 14,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (!isGraded) const SizedBox(width: 12),
                                if (!isGraded)
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF00F5FF),
                                            Color(0xFF00D4FF),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _showGradeDialog(
                                            context,
                                            submissions[index].reference,
                                            data['studentName'] ?? 'Student',
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.grade,
                                                  color: Colors.black,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 4),
                                                const Text(
                                                  "Grade",
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
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
    );
  }

  void _showGradeDialog(
    BuildContext context,
    DocumentReference submissionRef,
    String studentName,
  ) {
    final gradeController = TextEditingController();
    final feedbackController = TextEditingController();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Grade $studentName"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: gradeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Grade (%)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Feedback",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (gradeController.text.isNotEmpty) {
                await submissionRef.update({
                  'grade': int.tryParse(gradeController.text) ?? 0,
                  'feedback': feedbackController.text.trim(),
                  'isGraded': true,
                  'gradedAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Grade submitted successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00F5FF),
              foregroundColor: Colors.black,
            ),
            child: const Text("Submit Grade"),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Fallback to OpenFile
      await OpenFile.open(url);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime? date) {
    if (date == null) return 'Unknown';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _formatDate(date);
  }
}
