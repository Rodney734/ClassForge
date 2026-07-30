import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AssignmentRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String _cacheKeyForCourse(String courseId) =>
      'cached_assignments_course_$courseId';

  static String _cacheKeyForLevel(int level) =>
      'cached_assignments_level_$level';

  static String _cacheKeyForLecturer(String lecturerId) =>
      'cached_assignments_lecturer_$lecturerId';

  Future<List<Map<String, dynamic>>> getAssignmentsForLevel(
    int level, {
    bool forceRefresh = false,
  }) async {
    final cached = await _getCachedAssignmentsForLevel(level);
    if (!forceRefresh && cached.isNotEmpty) {
      return cached;
    }

    try {
      final snapshot = await _db
          .collection('assignments')
          .where('level', isEqualTo: level)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final assignments = snapshot.docs.map((doc) => doc.data()).toList();
      if (assignments.isNotEmpty) {
        await _cacheAssignmentsForLevel(level, assignments);
      }
      return assignments;
    } catch (_) {
      return cached;
    }
  }

  Future<List<Map<String, dynamic>>> getAssignmentsForLecturer(
    String lecturerId, {
    bool forceRefresh = false,
  }) async {
    final cached = await _getCachedAssignmentsForLecturer(lecturerId);
    if (!forceRefresh && cached.isNotEmpty) {
      return cached;
    }

    try {
      final snapshot = await _db
          .collection('assignments')
          .where('lecturerId', isEqualTo: lecturerId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final assignments = snapshot.docs.map((doc) => doc.data()).toList();
      if (assignments.isNotEmpty) {
        await _cacheAssignmentsForLecturer(lecturerId, assignments);
      }
      return assignments;
    } catch (_) {
      return cached;
    }
  }

  Future<List<Map<String, dynamic>>> getAssignmentsForCourse(
    String courseId, {
    bool forceRefresh = false,
  }) async {
    final cached = await _getCachedAssignmentsForCourse(courseId);
    if (!forceRefresh && cached.isNotEmpty) {
      return cached;
    }

    try {
      final snapshot = await _db
          .collection('assignments')
          .where('courseId', isEqualTo: courseId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final assignments = snapshot.docs.map((doc) => doc.data()).toList();
      if (assignments.isNotEmpty) {
        await _cacheAssignmentsForCourse(courseId, assignments);
      }
      return assignments;
    } catch (_) {
      return cached;
    }
  }

  Future<List<Map<String, dynamic>>> getCachedAssignmentsForCourse(
    String courseId,
  ) async {
    return _getCachedAssignmentsForCourse(courseId);
  }

  Future<void> _cacheAssignmentsForCourse(
    String courseId,
    List<Map<String, dynamic>> assignments,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKeyForCourse(courseId),
      jsonEncode(assignments),
    );
  }

  Future<void> _cacheAssignmentsForLevel(
    int level,
    List<Map<String, dynamic>> assignments,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKeyForLevel(level), jsonEncode(assignments));
  }

  Future<void> _cacheAssignmentsForLecturer(
    String lecturerId,
    List<Map<String, dynamic>> assignments,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKeyForLecturer(lecturerId),
      jsonEncode(assignments),
    );
  }

  Future<List<Map<String, dynamic>>> _getCachedAssignmentsForCourse(
    String courseId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKeyForCourse(courseId));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((map) => Map<String, dynamic>.from(map))
            .toList();
      }
    } catch (_) {
      return [];
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> _getCachedAssignmentsForLevel(
    int level,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKeyForLevel(level));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((map) => Map<String, dynamic>.from(map))
            .toList();
      }
    } catch (_) {
      return [];
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> _getCachedAssignmentsForLecturer(
    String lecturerId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKeyForLecturer(lecturerId));
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((map) => Map<String, dynamic>.from(map))
            .toList();
      }
    } catch (_) {
      return [];
    }

    return [];
  }
}
