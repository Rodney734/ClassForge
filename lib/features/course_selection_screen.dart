import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/course_model.dart';
import '../models/lecturer_assignment_model.dart';
import '../models/student_enrollment_model.dart';
import '../services/academic_structure_service.dart';
import '../services/auth_service.dart';

class CourseSelectionScreen extends StatefulWidget {
  const CourseSelectionScreen({super.key});

  @override
  State<CourseSelectionScreen> createState() => _CourseSelectionScreenState();
}

class _CourseSelectionScreenState extends State<CourseSelectionScreen> {
  final AcademicStructureService _academicService = AcademicStructureService();
  List<Course> _courses = [];
  List<StudentEnrollment> _enrollments = [];
  List<LecturerAssignment> _assignments = [];
  final Set<String> _selectedCourseIds = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    try {
      final courses = user.academicYearId != null && user.bachelorId != null
          ? await _academicService.getCoursesByBachelor(
              user.bachelorId!,
              user.academicYearId!,
            )
          : <Course>[];
      final enrollments = user.role == 'student'
          ? await _academicService.getStudentEnrollments(user.uid)
          : <StudentEnrollment>[];
      final assignments = user.role == 'lecturer'
          ? await _academicService.getLecturerAssignments(user.uid)
          : <LecturerAssignment>[];

      if (!mounted) return;
      setState(() {
        _courses = courses;
        _enrollments = enrollments;
        _assignments = assignments;
        _selectedCourseIds.addAll(
          user.role == 'student'
              ? enrollments
                    .where((item) => item.status == 'active')
                    .map((item) => item.courseId)
              : assignments
                    .where((item) => item.status == 'active')
                    .map((item) => item.courseId),
        );
        _isLoading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSelection() async {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      if (user.role == 'student') {
        final existing = {for (final item in _enrollments) item.courseId: item};
        for (final course in _courses) {
          final enrollment = existing[course.id];
          final shouldBeActive = _selectedCourseIds.contains(course.id);
          if (enrollment == null && shouldBeActive) {
            await _academicService.createStudentEnrollment(
              StudentEnrollment(
                id: const Uuid().v4(),
                studentId: user.uid,
                courseId: course.id,
                academicYearId: course.academicYearId,
                academicFieldId: course.academicFieldId,
                bachelorId: course.bachelorId,
                enrolledAt: DateTime.now(),
              ),
            );
          } else if (enrollment != null &&
              (enrollment.status == 'active') != shouldBeActive) {
            await _academicService.updateStudentEnrollmentStatus(
              enrollment.id,
              shouldBeActive ? 'active' : 'dropped',
            );
          }
        }
      } else {
        final existing = {for (final item in _assignments) item.courseId: item};
        for (final course in _courses) {
          final assignment = existing[course.id];
          final shouldBeActive = _selectedCourseIds.contains(course.id);
          if (assignment == null && shouldBeActive) {
            await _academicService.createLecturerAssignment(
              LecturerAssignment(
                id: const Uuid().v4(),
                lecturerId: user.uid,
                courseId: course.id,
                academicYearId: course.academicYearId,
                academicFieldId: course.academicFieldId,
                bachelorId: course.bachelorId,
                assignedAt: DateTime.now(),
              ),
            );
          } else if (assignment != null &&
              (assignment.status == 'active') != shouldBeActive) {
            await _academicService.updateLecturerAssignmentStatus(
              assignment.id,
              shouldBeActive ? 'active' : 'inactive',
            );
          }
        }
      }

      final activeCourse = _courses
          .where((course) => _selectedCourseIds.contains(course.id))
          .firstOrNull;
      if (activeCourse != null) {
        await auth.updateActiveCourse(
          courseId: activeCourse.id,
          courseName: activeCourse.name,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subjects updated successfully.')),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update subjects: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final roleLabel = user?.role == 'lecturer' ? 'teaching' : 'enrolled';

    return Scaffold(
      appBar: AppBar(title: const Text('My Subjects')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _courses.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No subjects are available under your selected programme yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Choose the subjects you are $roleLabel in. You can change this later from your account.',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                ..._courses.map(
                  (course) => CheckboxListTile(
                    value: _selectedCourseIds.contains(course.id),
                    title: Text(course.name),
                    subtitle: Text(
                      '${course.code} • ${course.semester} semester',
                    ),
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedCourseIds.add(course.id);
                        } else {
                          _selectedCourseIds.remove(course.id);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveSelection,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save Subjects'),
                ),
              ],
            ),
    );
  }
}
