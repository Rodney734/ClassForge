import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'offline_sync_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==================== USERS ====================
  Future<void> saveUser(AppUser user) async {
    try {
      await _db.collection('users').doc(user.uid).set(user.toMap());
      await OfflineSyncService.cacheUserProfile(user);
    } catch (_) {
      await OfflineSyncService.cacheUserProfile(user);
      await OfflineSyncService.queuePendingSync(
        'user_profile',
        user.toMap(forCache: true),
      );
    }
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
    try {
      await _db.collection('users').doc(uid).update(data);
    } catch (_) {
      await OfflineSyncService.queuePendingSync('user_profile_update', {
        'uid': uid,
        'data': data,
      });
    }
  }

  /// Update active course/module for a user
  Future<void> updateActiveModule({
    required String uid,
    required String moduleId,
    required String moduleName,
    required String courseId,
    required String courseName,
  }) async {
    try {
      await _db.collection('users').doc(uid).update({
        'activeModuleId': moduleId,
        'activeModuleName': moduleName,
        'activeCourseId': courseId,
        'activeCourseName': courseName,
      });
    } catch (e) {
      print("❌ Error updating active module: $e");
      rethrow;
    }
  }

  // ==================== NOTICES ====================
  /// Deprecated: Old level-based notice method (kept for backward compatibility)
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

  /// Deprecated: Old level-based notice query (kept for backward compatibility)
  Stream<QuerySnapshot> getNotices(int level) {
    return _db
        .collection('notices')
        .where('level', isEqualTo: level)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// New: Course-based notice method
  Future<void> postNoticeToCourse({
    required String title,
    required String body,
    required String postedBy,
    required String courseId,
    required String academicYearId,
    required String academicFieldId,
    required String bachelorId,
    String? imageUrl,
  }) async {
    await _db.collection('notices').add({
      'title': title,
      'body': body,
      'postedBy': postedBy,
      'courseId': courseId,
      'academicYearId': academicYearId,
      'academicFieldId': academicFieldId,
      'bachelorId': bachelorId,
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'isImportant': false,
    });
  }

  /// New: Query notices by course
  Stream<QuerySnapshot> getNoticesByCourse(String courseId) {
    return _db
        .collection('notices')
        .where('courseId', isEqualTo: courseId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ==================== ASSIGNMENTS ====================
  /// Deprecated: Old level-based assignment method (kept for backward compatibility)
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

  /// Deprecated: Old level-based assignment query (kept for backward compatibility)
  Stream<QuerySnapshot> getAssignments(int level) {
    return _db
        .collection('assignments')
        .where('level', isEqualTo: level)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// New: Course-based assignment creation
  Future<void> createAssignmentForCourse({
    required String title,
    required String description,
    required String lecturerName,
    required String lecturerId,
    required String courseId,
    required String academicYearId,
    required String academicFieldId,
    required String bachelorId,
    String? fileUrl,
    String? fileName,
    DateTime? dueDate,
  }) async {
    await _db.collection('assignments').add({
      'title': title,
      'description': description,
      'lecturerName': lecturerName,
      'lecturerId': lecturerId,
      'courseId': courseId,
      'academicYearId': academicYearId,
      'academicFieldId': academicFieldId,
      'bachelorId': bachelorId,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'dueDate': dueDate,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// New: Query assignments by course
  Stream<QuerySnapshot> getAssignmentsByCourse(String courseId) {
    return _db
        .collection('assignments')
        .where('courseId', isEqualTo: courseId)
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

  // ==================== MESSAGES/CHAT ====================
  /// Deprecated: Old level-based messages (kept for backward compatibility)
  Stream<QuerySnapshot> getMessagesByLevel(int level) {
    return _db
        .collection('messages')
        .where('level', isEqualTo: level)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  /// New: Query messages by course
  Stream<QuerySnapshot> getMessagesByCourse(String courseId) {
    return _db
        .collection('messages')
        .where('courseId', isEqualTo: courseId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Send message to course chat
  Future<void> sendMessageToCourse({
    required String courseId,
    required String academicYearId,
    required String academicFieldId,
    required String bachelorId,
    required String senderId,
    required String senderName,
    required String message,
    String? fileUrl,
    String? fileName,
  }) async {
    try {
      await _db.collection('messages').add({
        'courseId': courseId,
        'academicYearId': academicYearId,
        'academicFieldId': academicFieldId,
        'bachelorId': bachelorId,
        'senderId': senderId,
        'senderName': senderName,
        'message': message,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }

  /// Deprecated: Old level-based typing status
  Future<void> sendTypingStatusByLevel({
    required int level,
    required String userId,
    required String userName,
    required bool isTyping,
  }) async {
    try {
      final docRef = _db
          .collection('typing_status')
          .doc('level_${level}_$userId');

      if (isTyping) {
        await docRef.set({
          'userId': userId,
          'userName': userName,
          'level': level,
          'isTyping': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.delete();
      }
    } catch (e) {
      print('❌ Error updating typing status: $e');
    }
  }

  /// New: Course-based typing status
  Future<void> sendTypingStatusByCourse({
    required String courseId,
    required String userId,
    required String userName,
    required bool isTyping,
  }) async {
    try {
      final docRef = _db
          .collection('typing_status')
          .doc('course_${courseId}_$userId');

      if (isTyping) {
        await docRef.set({
          'userId': userId,
          'userName': userName,
          'courseId': courseId,
          'isTyping': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.delete();
      }
    } catch (e) {
      print('❌ Error updating typing status: $e');
    }
  }

  /// Deprecated: Old level-based typing indicator listeners
  Stream<QuerySnapshot> getTypingStatusByLevel(int level) {
    return _db
        .collection('typing_status')
        .where('level', isEqualTo: level)
        .snapshots();
  }

  /// New: Course-based typing indicator listeners
  Stream<QuerySnapshot> getTypingStatusByCourse(String courseId) {
    return _db
        .collection('typing_status')
        .where('courseId', isEqualTo: courseId)
        .snapshots();
  }
}
