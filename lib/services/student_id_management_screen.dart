import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/student_id_service.dart';
import '../services/ocr_service.dart';

class StudentIdManagementScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const StudentIdManagementScreen({super.key, this.onBack});

  @override
  State<StudentIdManagementScreen> createState() =>
      _StudentIdManagementScreenState();
}

class _StudentIdManagementScreenState extends State<StudentIdManagementScreen> {
  final StudentIdService _studentIdService = StudentIdService();
  final OcrService _ocrService = OcrService();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _levelController = TextEditingController();

  bool _isLoading = false;
  List<String> _extractedIds = [];

  @override
  void dispose() {
    _studentIdController.dispose();
    _levelController.dispose();
    // ML Kit does not support Windows. Guarding the call to prevent MissingPluginException during screen disposal.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      _ocrService.dispose();
    }
    super.dispose();
  }

  Future<void> _addStudentIdManually() async {
    if (_studentIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Student ID')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user == null || user.role != 'lecturer') {
        throw Exception('Lecturer profile not loaded. Please re-login.');
      }

      final level = int.tryParse(_levelController.text.trim()) ?? 4;

      await _studentIdService.addStudentId(
        studentId: _studentIdController.text.trim().toUpperCase(),
        lecturerId: user.uid,
        lecturerName: user.fullName,
        level: level,
      );

      _studentIdController.clear();
      _levelController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student ID added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importFromImage() async {
    // OCR features are not available on Desktop/Windows.
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Student ID scanning (OCR) is only supported on Android and iOS devices.',
          ),
        ),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final File imageFile = File(image.path);
      final extractedIds = await _ocrService.extractStudentIdsFromImage(
        imageFile,
      );

      setState(() {
        _extractedIds = extractedIds;
      });

      if (extractedIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No student IDs found in the image. Please try again.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        _showExtractedIdsDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('OCR Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showExtractedIdsDialog() {
    final user = Provider.of<AuthService>(context, listen: false).currentUser;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selectedIds = <String, bool>{};
          for (var id in _extractedIds) {
            selectedIds[id] = true;
          }

          return AlertDialog(
            title: const Text('Extracted Student IDs'),
            content: SizedBox(
              width: 400,
              height: 400,
              child: Column(
                children: [
                  Text('Found ${_extractedIds.length} student IDs'),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _extractedIds.length,
                      itemBuilder: (context, index) {
                        final id = _extractedIds[index];
                        return CheckboxListTile(
                          title: Text(id),
                          value: selectedIds[id],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedIds[id] = value ?? false;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _isLoading = true);

                  final idsToAdd = selectedIds.entries
                      .where((e) => e.value)
                      .map((e) => e.key)
                      .toList();

                  final List<Map<String, dynamic>> batchData = idsToAdd
                      .map(
                        (id) => {
                          'studentId': id,
                          'lecturerId': user?.uid ?? '',
                          'lecturerName': user?.fullName ?? '',
                          'level': user?.level ?? 4,
                          'isActive': true,
                          'isUsed': false,
                        },
                      )
                      .toList();

                  await _studentIdService.addMultipleStudentIds(batchData);

                  setState(() => _isLoading = false);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Added ${idsToAdd.length} student IDs successfully!',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                    setState(() => _extractedIds = []);
                  }
                },
                child: Text(
                  'Add Selected (${selectedIds.values.where((v) => v).length})',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleStudentStatus(String id, bool isActive) async {
    if (isActive) {
      await _studentIdService.deactivateStudentId(id);
    } else {
      await _studentIdService.reactivateStudentId(id);
    }
  }

  Future<void> _deleteStudentId(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student ID?'),
        content: Text(
          'Are you sure you want to delete $id? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _studentIdService.deleteStudentId(id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Student ID deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 32 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Section
                        _buildHeader(isDarkMode),
                        const SizedBox(height: 24),

                        // Manual Entry Card
                        _buildManualEntryCard(isDarkMode, isDesktop),
                        const SizedBox(height: 24),

                        // OCR Import Card
                        _buildOcrImportCard(isDarkMode),
                        const SizedBox(height: 24),

                        // Student IDs List
                        _buildStudentIdsList(isDarkMode, user),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.redAccent.withValues(alpha: 0.2),
            Colors.purple.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (widget.onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.redAccent),
              onPressed: widget.onBack,
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.verified_user,
              color: Colors.redAccent,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Student ID Verification',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Add and manage valid student IDs for registration',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.redAccent),
            onPressed: () => _showHelpDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntryCard(bool isDarkMode, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.08),
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note, color: Colors.redAccent),
              const SizedBox(width: 8),
              const Text(
                'Manual Entry',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _studentIdController,
                  decoration: const InputDecoration(
                    labelText: 'Student ID',
                    hintText: 'e.g., 2024-001 or STU001',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _levelController,
                  decoration: const InputDecoration(
                    labelText: 'Level',
                    hintText: '1-6',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _addStudentIdManually,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOcrImportCard(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.08),
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.document_scanner, color: Colors.redAccent),
              const SizedBox(width: 8),
              const Text(
                'Import from Image (OCR)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Upload a photo or screenshot of a class list containing student IDs. '
            'The system will automatically extract and detect IDs.',
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _importFromImage,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Import from Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _importFromImage,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take a Photo'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentIdsList(bool isDarkMode, user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.08),
            (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, color: Colors.redAccent),
              const SizedBox(width: 8),
              const Text(
                'Registered Student IDs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _studentIdService.getStudentIds(user?.uid ?? ''),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No student IDs added yet',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add student IDs using manual entry or OCR import',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final students = snapshot.data!.docs;
              final activeCount = students
                  .where((doc) => doc['isActive'] == true)
                  .length;
              final inactiveCount = students
                  .where((doc) => doc['isActive'] == false)
                  .length;

              return Column(
                children: [
                  // Stats
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              activeCount.toString(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const Text(
                              'Active',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 30, color: Colors.grey),
                        Column(
                          children: [
                            Text(
                              inactiveCount.toString(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const Text(
                              'Inactive',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 30, color: Colors.grey),
                        Column(
                          children: [
                            Text(
                              students.length.toString(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text('Total', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final data = student.data() as Map<String, dynamic>;
                      final isActive = data['isActive'] ?? true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: (isDarkMode ? Colors.white : Colors.black)
                              .withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isActive
                                ? Colors.green.withValues(alpha: 0.3)
                                : Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isActive
                                ? Colors.green.withValues(alpha: 0.2)
                                : Colors.red.withValues(alpha: 0.2),
                            child: Text(
                              data['studentId'][0].toUpperCase(),
                              style: TextStyle(
                                color: isActive ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            data['studentId'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Level ${data['level'] ?? 1}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: isActive,
                                onChanged: (_) => _toggleStudentStatus(
                                  data['studentId'],
                                  isActive,
                                ),
                                activeThumbColor: Colors.green,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _deleteStudentId(data['studentId']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How to Use Student ID Management'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpItem(
                'Manual Entry',
                'Type individual student IDs and level. Click Add to save.',
                Icons.edit_note,
              ),
              const SizedBox(height: 16),
              _buildHelpItem(
                'OCR Import',
                'Upload an image containing student IDs. The system will automatically detect and extract them.',
                Icons.document_scanner,
              ),
              const SizedBox(height: 16),
              _buildHelpItem(
                'Student ID Format',
                'Supported formats: 2024-001, STU001, or any 6-10 digit number',
                Icons.info_outline,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.redAccent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(description, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
