import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class LiveClassService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Callable function to get chat and reactions
  Future<Map<String, dynamic>> getLiveClassData(int level) async {
    try {
      final callable = _functions.httpsCallable('getLiveClassData');
      final response = await callable.call({'level': level});
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      print("Error calling getLiveClassData: $e");
      rethrow;
    }
  }

  // Send a chat message
  Future<void> sendChatMessage({
    required int level,
    required String message,
    required String userId,
    required String userName,
  }) async {
    await _db.collection('live_class_chat').add({
      'level': level,
      'message': message,
      'userId': userId,
      'userName': userName,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Send a reaction
  Future<void> sendReaction({
    required int level,
    required String reaction,
    required String userId,
    required String userName,
  }) async {
    await _db.collection('live_class_reactions').add({
      'level': level,
      'reaction': reaction,
      'userId': userId,
      'userName': userName,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Start a live class (lecturer)
  Future<void> startLiveClass({
    required int level,
    required String className,
    required String lecturerId,
    required String lecturerName,
  }) async {
    final docRef = _db.collection('live_classes').doc('level_$level');
    await docRef.set({
      'className': className,
      'lecturerId': lecturerId,
      'lecturerName': lecturerName,
      'isLive': true,
      'startedAt': FieldValue.serverTimestamp(),
      'participants': {},
    });
  }

  // End a live class (lecturer)
  Future<void> endLiveClass(int level) async {
    final docRef = _db.collection('live_classes').doc('level_$level');
    await docRef.update({'isLive': false});
  }

  // Join a class (student)
  Future<void> joinClass({
    required int level,
    required String studentId,
    required String studentName,
  }) async {
    final docRef = _db.collection('live_classes').doc('level_$level');
    await docRef.update({
      'participants.$studentId': {
        'name': studentName,
        'joinedAt': FieldValue.serverTimestamp(),
      },
    });
  }

  // Leave a class (student)
  Future<void> leaveClass({required int level, required String userId}) async {
    final docRef = _db.collection('live_classes').doc('level_$level');
    await docRef.update({'participants.$userId': FieldValue.delete()});
  }
}
