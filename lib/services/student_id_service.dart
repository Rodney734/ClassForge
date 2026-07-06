import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
//import 'dart:io';

class StudentIdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save a single student ID
  Future<void> addStudentId({
    required String studentId,
    required String lecturerId,
    required String lecturerName,
    required int level,
  }) async {
    await _firestore.collection('valid_student_ids').doc(studentId).set({
      'studentId': studentId,
      'lecturerId': lecturerId,
      'lecturerName': lecturerName,
      'level': level,
      'isActive': true,
      'isUsed': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Add multiple student IDs
  Future<void> addMultipleStudentIds(
    List<Map<String, dynamic>> students,
  ) async {
    final batch = _firestore.batch();

    for (var student in students) {
      final docRef = _firestore
          .collection('valid_student_ids')
          .doc(student['studentId']);
      batch.set(docRef, {
        ...student,
        'isActive': student['isActive'] ?? true,
        'isUsed': student['isUsed'] ?? false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // Get all student IDs for a lecturer
  Stream<QuerySnapshot> getStudentIds(String lecturerId) {
    return _firestore
        .collection('valid_student_ids')
        .where('lecturerId', isEqualTo: lecturerId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Check if student ID is valid
  Future<bool> isValidStudentId(String studentId) async {
    try {
      final doc = await _firestore
          .collection('valid_student_ids')
          .doc(studentId)
          .get();

      if (!doc.exists) return false;
      final data = doc.data()!;
      return (data['isActive'] ?? false) && !(data['isUsed'] ?? false);
    } catch (e) {
      print("Error validating Student ID: $e");
      return false;
    }
  }

  // Deactivate a student ID
  Future<void> deactivateStudentId(String studentId) async {
    await _firestore.collection('valid_student_ids').doc(studentId).update({
      'isActive': false,
      'deactivatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Reactivate a student ID
  Future<void> reactivateStudentId(String studentId) async {
    await _firestore.collection('valid_student_ids').doc(studentId).update({
      'isActive': true,
    });
  }

  // Delete a student ID permanently
  Future<void> deleteStudentId(String studentId) async {
    await _firestore.collection('valid_student_ids').doc(studentId).delete();
  }

  // Get student count
  Future<int> getStudentCount(String lecturerId) async {
    final snapshot = await _firestore
        .collection('valid_student_ids')
        .where('lecturerId', isEqualTo: lecturerId)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.length;
  }
}
