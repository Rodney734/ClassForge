import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/user_model.dart';

class OfflineSyncService {
  static const String _cachedUserKey = 'cached_user_profile';
  static const String _pendingSyncKey = 'pending_sync_actions';

  static Future<void> cacheUserProfile(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cachedUserKey,
      jsonEncode(user.toMap(forCache: true)),
    );
  }

  static Future<AppUser?> getCachedUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedUserKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AppUser.fromMap(decoded);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static Future<void> queuePendingSync(
    String actionType,
    Map<String, dynamic> payload,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getPendingSyncActions();

    current.add({
      'id': const Uuid().v4(),
      'type': actionType,
      'payload': payload,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });

    await prefs.setString(_pendingSyncKey, jsonEncode(current));
  }

  static Future<List<Map<String, dynamic>>> getPendingSyncActions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingSyncKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {
      return [];
    }

    return [];
  }

  static Future<void> removePendingSync(String actionId) async {
    final prefs = await SharedPreferences.getInstance();
    final actions = await getPendingSyncActions();
    final filtered = actions
        .where((action) => action['id'] != actionId)
        .toList();
    await prefs.setString(_pendingSyncKey, jsonEncode(filtered));
  }

  static Future<void> clearPendingSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingSyncKey);
  }
}
