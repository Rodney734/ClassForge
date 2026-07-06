import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class ForumService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Post a new question
  Future<void> askQuestion({
    required String text,
    required AppUser user,
  }) async {
    await _firestore.collection('forum_questions').add({
      'askerId': user.uid,
      'askerName': user.fullName,
      'askerProfilePicture': user.profilePicture,
      'level': user.level,
      'questionText': text,
      'isResolved': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Get questions for a specific level
  Stream<QuerySnapshot> getQuestions(int level) {
    return _firestore
        .collection('forum_questions')
        .where('level', isEqualTo: level)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Post an answer to a question
  Future<void> submitAnswer({
    required String questionId,
    required String text,
    required AppUser user,
  }) async {
    await _firestore
        .collection('forum_questions')
        .doc(questionId)
        .collection('answers')
        .add({
          'answererId': user.uid,
          'answererName': user.fullName,
          'answererProfilePicture': user.profilePicture,
          'answerText': text,
          'status': 'pending', // pending, correct, incorrect
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  // Get answers for a specific question
  Stream<QuerySnapshot> getAnswers(String questionId) {
    return _firestore
        .collection('forum_questions')
        .doc(questionId)
        .collection('answers')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Verify an answer and update the answerer's streak
  Future<void> evaluateAnswer({
    required String questionId,
    required String answerId,
    required String answererId,
    required bool isCorrect,
  }) async {
    final answerRef = _firestore
        .collection('forum_questions')
        .doc(questionId)
        .collection('answers')
        .doc(answerId);

    final userRef = _firestore.collection('users').doc(answererId);
    final questionRef = _firestore
        .collection('forum_questions')
        .doc(questionId);

    await _firestore.runTransaction((transaction) async {
      // 1. Update answer status
      transaction.update(answerRef, {
        'status': isCorrect ? 'correct' : 'incorrect',
      });

      // 2. Update answerer's streak
      final userSnapshot = await transaction.get(userRef);
      if (userSnapshot.exists) {
        int currentStreak = userSnapshot.data()?['streak'] ?? 0;
        int newStreak = isCorrect ? currentStreak + 1 : currentStreak - 1;

        // Ensure streak doesn't go below 0
        transaction.update(userRef, {'streak': newStreak < 0 ? 0 : newStreak});
      }

      // 3. If correct, mark the question as resolved
      if (isCorrect) {
        transaction.update(questionRef, {'isResolved': true});
      }
    });
  }
}
