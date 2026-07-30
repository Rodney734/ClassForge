import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course_model.dart';
import 'academic_structure_service.dart';

class CourseRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AcademicStructureService _academicStructureService =
      AcademicStructureService();

  static String _cacheKeyForLecturer(String lecturerId) =>
      'cached_courses_lecturer_$lecturerId';

  Future<List<Course>> getCoursesForLecturer(
    String lecturerId, {
    bool forceRefresh = false,
  }) async {
    final cached = await _getCachedCoursesForLecturer(lecturerId);
    if (!forceRefresh && cached.isNotEmpty) {
      return cached;
    }

    try {
      final remoteCourses = await _academicStructureService
          .getCoursesByLecturer(lecturerId);
      if (remoteCourses.isNotEmpty) {
        await _cacheCoursesForLecturer(lecturerId, remoteCourses);
      }
      return remoteCourses;
    } catch (_) {
      return cached;
    }
  }

  Future<List<Course>> getCachedCoursesForLecturer(String lecturerId) async {
    return _getCachedCoursesForLecturer(lecturerId);
  }

  Future<void> _cacheCoursesForLecturer(
    String lecturerId,
    List<Course> courses,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = courses.map((course) => course.toMap()).toList();
    await prefs.setString(
      _cacheKeyForLecturer(lecturerId),
      jsonEncode(payload),
    );
  }

  Future<List<Course>> _getCachedCoursesForLecturer(String lecturerId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKeyForLecturer(lecturerId));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((map) => Course.fromMap(Map<String, dynamic>.from(map)))
            .toList();
      }
    } catch (_) {
      return [];
    }

    return [];
  }
}
