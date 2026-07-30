import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NoticeRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String _cacheKeyForCourse(String courseId) =>
      'cached_notices_course_$courseId';

  static String _cacheKeyForLevel(int level) => 'cached_notices_level_$level';

  Future<List<Map<String, dynamic>>> getNoticesForLevel(
    int level, {
    bool forceRefresh = false,
  }) async {
    final cached = await _getCachedNoticesForLevel(level);
    if (!forceRefresh && cached.isNotEmpty) {
      return cached;
    }

    try {
      final snapshot = await _db
          .collection('notices')
          .where('level', isEqualTo: level)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final notices = snapshot.docs.map((doc) => doc.data()).toList();
      if (notices.isNotEmpty) {
        await _cacheNoticesForLevel(level, notices);
      }
      return notices;
    } catch (_) {
      return cached;
    }
  }

  Future<List<Map<String, dynamic>>> getCachedNoticesForLevel(int level) async {
    return _getCachedNoticesForLevel(level);
  }

  Future<List<Map<String, dynamic>>> getNoticesForCourse(
    String courseId, {
    bool forceRefresh = false,
  }) async {
    final cached = await _getCachedNoticesForCourse(courseId);
    if (!forceRefresh && cached.isNotEmpty) {
      return cached;
    }

    try {
      final snapshot = await _db
          .collection('notices')
          .where('courseId', isEqualTo: courseId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final notices = snapshot.docs.map((doc) => doc.data()).toList();
      if (notices.isNotEmpty) {
        await _cacheNoticesForCourse(courseId, notices);
      }
      return notices;
    } catch (_) {
      return cached;
    }
  }

  Future<List<Map<String, dynamic>>> getCachedNoticesForCourse(
    String courseId,
  ) async {
    return _getCachedNoticesForCourse(courseId);
  }

  Future<void> _cacheNoticesForCourse(
    String courseId,
    List<Map<String, dynamic>> notices,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKeyForCourse(courseId), jsonEncode(notices));
  }

  Future<void> _cacheNoticesForLevel(
    int level,
    List<Map<String, dynamic>> notices,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKeyForLevel(level), jsonEncode(notices));
  }

  Future<List<Map<String, dynamic>>> _getCachedNoticesForCourse(
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

  Future<List<Map<String, dynamic>>> _getCachedNoticesForLevel(
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
}
