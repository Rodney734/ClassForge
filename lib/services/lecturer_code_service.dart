import 'package:cloud_firestore/cloud_firestore.dart';

class LecturerCodeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Validate a lecturer registration code
  /// Returns a [LecturerCodeValidationResult] with validation status
  Future<LecturerCodeValidationResult> validateCode(String code) async {
    try {
      // Trim and uppercase the code for consistency
      final trimmedCode = code.trim().toUpperCase();

      // Query for the code in Firestore
      final querySnapshot = await _firestore
          .collection('lecturer_codes')
          .where('code', isEqualTo: trimmedCode)
          .limit(1)
          .get();

      // Check if code exists
      if (querySnapshot.docs.isEmpty) {
        return LecturerCodeValidationResult(
          isValid: false,
          message: 'Invalid lecturer registration code.',
          documentId: null,
        );
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();

      // Check if code has already been used
      final bool isUsed = data['used'] ?? false;

      if (isUsed) {
        return LecturerCodeValidationResult(
          isValid: false,
          message: 'This registration code has already been used.',
          documentId: doc.id,
        );
      }

      // Code is valid
      return LecturerCodeValidationResult(
        isValid: true,
        message: 'Code is valid.',
        documentId: doc.id,
      );
    } catch (e) {
      return LecturerCodeValidationResult(
        isValid: false,
        message: 'Error validating code. Please try again.',
        documentId: null,
      );
    }
  }

  /// Mark a code as used by a user
  Future<void> markCodeAsUsed(String documentId, String userId) async {
    await _firestore.collection('lecturer_codes').doc(documentId).update({
      'used': true,
      'usedBy': userId,
      'usedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Check if a code exists and is valid (for real-time validation)
  Stream<DocumentSnapshot?> watchCodeStatus(String code) {
    final trimmedCode = code.trim().toUpperCase();
    return _firestore
        .collection('lecturer_codes')
        .where('code', isEqualTo: trimmedCode)
        .limit(1)
        .snapshots()
        .map((querySnapshot) {
          if (querySnapshot.docs.isEmpty) return null;
          return querySnapshot.docs.first;
        });
  }

  /// Create a new lecturer code (for admin use)
  Future<void> createCode(String code) async {
    await _firestore.collection('lecturer_codes').add({
      'code': code.trim().toUpperCase(),
      'used': false,
      'usedBy': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get all lecturer codes (for admin use)
  Future<List<Map<String, dynamic>>> getAllCodes() async {
    final snapshot = await _firestore
        .collection('lecturer_codes')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'code': data['code'],
        'used': data['used'] ?? false,
        'usedBy': data['usedBy'],
        'usedAt': (data['usedAt'] as Timestamp?)?.toDate(),
        'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
      };
    }).toList();
  }

  /// Delete a lecturer code (for admin use)
  Future<void> deleteCode(String documentId) async {
    await _firestore.collection('lecturer_codes').doc(documentId).delete();
  }
}

/// Result model for code validation
class LecturerCodeValidationResult {
  final bool isValid;
  final String message;
  final String? documentId;

  LecturerCodeValidationResult({
    required this.isValid,
    required this.message,
    this.documentId,
  });
}
