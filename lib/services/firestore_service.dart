import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==================== USERS ====================
  Future<void> saveUser(AppUser user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<AppUser?> getUser(String uid) async {
    try {
      // Use serverAndCache but force a fresh look if debugging on Web
      final doc = await _db
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.serverAndCache));
      if (doc.exists) {
        return AppUser.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print("❌ FirestoreService.getUser Error: $e");
      rethrow; // Rethrow to let AuthService handle the specific error
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  // ==================== NOTICES ====================
  Future<void> postNotice({
    required String title,
    required String body,
    required String postedBy,
    required int level,
    String? imageUrl,
  }) async {
    await _db.collection('notices').add({
      'title': title,
      'body': body,
      'postedBy': postedBy,
      'level': level,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'isImportant': false,
    });
  }

  Stream<QuerySnapshot> getNotices(int level) {
    return _db
        .collection('notices')
        .where('level', isEqualTo: level)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ==================== ASSIGNMENTS ====================

  Future<void> createAssignment({
    required String title,
    required String description,
    required String lecturerName,
    required int level,
    String? fileUrl,
    String? fileName,
    DateTime? dueDate,
  }) async {
    await _db.collection('assignments').add({
      'title': title,
      'description': description,
      'lecturerName': lecturerName,
      'level': level,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'dueDate': dueDate,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getAssignments(int level) {
    return _db
        .collection('assignments')
        .where('level', isEqualTo: level)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Submit Assignment
  Future<void> submitAssignment({
    required String assignmentId,
    required String studentId,
    required String studentName,
    required String fileUrl,
    required String fileName,
  }) async {
    await _db
        .collection('assignments')
        .doc(assignmentId)
        .collection('submissions')
        .add({
          'studentId': studentId,
          'studentName': studentName,
          'fileUrl': fileUrl,
          'fileName': fileName,
          'submittedAt': FieldValue.serverTimestamp(),
        });
  }
}
