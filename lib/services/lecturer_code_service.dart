import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LecturerCodeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Validates a lecturer registration code.
  ///
  /// Returns `true` if the code exists and has not been used, `false` otherwise.
  /// This version does NOT mark the code as used.
  Future<bool> isCodeValid(String code) async {
    final query = await _db
        .collection('lecturer_codes')
        .where('code', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return false;

    final codeData = query.docs.first.data();
    return codeData['used'] == false;
  }

  /// Validates and marks a lecturer registration code as used.
  ///
  /// Returns `true` if the code was successfully validated and marked as used.
  Future<bool> validateAndUseCode(String code) async {
    final query = await _db
        .collection('lecturer_codes')
        .where('code', isEqualTo: code.trim().toUpperCase())
        .where('used', isEqualTo: false)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return false;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    await query.docs.first.reference.update({'used': true, 'usedBy': uid});
    return true;
  }
}
