import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/user_model.dart';
import 'offline_sync_service.dart';

class SyncManager {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> syncPendingActions() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return;
    }

    final actions = await OfflineSyncService.getPendingSyncActions();
    if (actions.isEmpty) return;

    for (final action in actions) {
      final type = action['type'] as String?;
      final payload = Map<String, dynamic>.from(action['payload'] ?? {});
      final actionId = action['id'] as String? ?? '';

      try {
        if (type == 'user_profile') {
          final user = AppUser.fromMap(payload);
          await _db
              .collection('users')
              .doc(user.uid)
              .set(user.toMap(), SetOptions(merge: true));
        }

        if (type == 'user_profile_update') {
          final uid = payload['uid'] as String?;
          final data = Map<String, dynamic>.from(payload['data'] ?? {});
          if (uid != null && uid.isNotEmpty) {
            await _db.collection('users').doc(uid).update(data);
          }
        }
      } catch (_) {
        return;
      }

      if (actionId.isNotEmpty) {
        await OfflineSyncService.removePendingSync(actionId);
      }
    }
  }
}
