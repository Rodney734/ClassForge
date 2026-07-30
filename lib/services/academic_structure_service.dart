import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/academic_year_model.dart';
import '../models/academic_field_model.dart';
import '../models/bachelor_model.dart';
import '../models/course_model.dart';
import '../models/student_enrollment_model.dart';
import '../models/lecturer_assignment_model.dart';

class AcademicStructureService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _institution = 'MAGU'; // Default to MAGU

  // ==================== ACADEMIC YEARS ====================
  Future<List<AcademicYear>> getAcademicYears({String? institution}) async {
    try {
      final inst = institution ?? _institution;
      final snapshot = await _db.collection('academic_years').get();

      final years = snapshot.docs
          .map((doc) => AcademicYear.fromMap(doc.data()))
          .where((year) => year.institution == inst && year.isActive)
          .toList();
      years.sort((first, second) => first.level.compareTo(second.level));
      return years;
    } catch (e) {
      print('❌ Error fetching academic years: $e');
      rethrow;
    }
  }

  Future<AcademicYear?> getAcademicYear(String yearId) async {
    try {
      final doc = await _db.collection('academic_years').doc(yearId).get();
      if (doc.exists) {
        return AcademicYear.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ Error fetching academic year: $e');
      return null;
    }
  }

  // ==================== ACADEMIC FIELDS ====================
  /// Get all active academic fields
  Future<List<AcademicField>> getAcademicFields({String? institution}) async {
    try {
      final inst = institution ?? _institution;
      final snapshot = await _db.collection('academic_fields').get();

      final loadedFields = snapshot.docs
          .map((doc) => AcademicField.fromMap(doc.data()))
          .where((field) => field.institution == inst && field.isActive)
          .toList();
      final fieldsByKey = <String, AcademicField>{};
      for (final field in loadedFields) {
        final key = field.name.trim().isNotEmpty
            ? field.name.trim().toLowerCase()
            : field.code.trim().toLowerCase();
        fieldsByKey.putIfAbsent(key, () => field);
      }
      final fields = fieldsByKey.values.toList();
      fields.sort((first, second) => first.name.compareTo(second.name));
      return fields;
    } catch (e) {
      print('❌ Error fetching academic fields: $e');
      rethrow;
    }
  }

  Future<AcademicField?> getAcademicField(String fieldId) async {
    try {
      final doc = await _db.collection('academic_fields').doc(fieldId).get();
      if (doc.exists) {
        return AcademicField.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ Error fetching academic field: $e');
      return null;
    }
  }

  // ==================== BACHELORS/DEGREES ====================
  /// Get all bachelor programmes in an academic field
  Future<List<Bachelor>> getBachelorsByField(
    String fieldId, {
    String? institution,
  }) async {
    try {
      final inst = institution ?? _institution;
      final snapshot = await _db
          .collection('bachelors')
          .where('institution', isEqualTo: inst)
          .where('academicFieldId', isEqualTo: fieldId)
          .where('isActive', isEqualTo: true)
          .get();

      final bachelors = snapshot.docs
          .map((doc) => Bachelor.fromMap(doc.data()))
          .toList();
      bachelors.sort((first, second) => first.name.compareTo(second.name));
      return bachelors;
    } catch (e) {
      print('❌ Error fetching bachelors by field: $e');
      return [];
    }
  }

  Future<Bachelor?> getBachelor(String bachelorId) async {
    try {
      final doc = await _db.collection('bachelors').doc(bachelorId).get();
      if (doc.exists) {
        return Bachelor.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ Error fetching bachelor: $e');
      return null;
    }
  }

  // ==================== COURSES ====================
  /// Get all courses for a specific bachelor programme in a specific year
  Future<List<Course>> getCoursesByBachelor(
    String bachelorId,
    String academicYearId, {
    String? institution,
  }) async {
    try {
      final inst = institution ?? _institution;
      final snapshot = await _db
          .collection('courses')
          .where('institution', isEqualTo: inst)
          .where('academicYearId', isEqualTo: academicYearId)
          .where('bachelorId', isEqualTo: bachelorId)
          .where('isActive', isEqualTo: true)
          .get();

      final courses = snapshot.docs
          .map((doc) => Course.fromMap(doc.data()))
          .toList();
      courses.sort((first, second) => first.name.compareTo(second.name));
      return courses;
    } catch (e) {
      print('❌ Error fetching courses by bachelor: $e');
      return [];
    }
  }

  /// Get all courses taught by a lecturer
  Future<List<Course>> getCoursesByLecturer(String lecturerId) async {
    try {
      final snapshot = await _db
          .collection('courses')
          .where('lecturerIds', arrayContains: lecturerId)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) => Course.fromMap(doc.data())).toList();
    } catch (e) {
      print('❌ Error fetching lecturer courses: $e');
      return [];
    }
  }

  Future<Course?> getCourse(String courseId) async {
    try {
      final doc = await _db.collection('courses').doc(courseId).get();
      if (doc.exists) {
        return Course.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ Error fetching course: $e');
      return null;
    }
  }

  // ==================== STUDENT ENROLLMENTS ====================
  /// Get active enrollments for a student
  Future<List<StudentEnrollment>> getStudentEnrollments(
    String studentId,
  ) async {
    try {
      final snapshot = await _db
          .collection('student_enrollments')
          .where('studentId', isEqualTo: studentId)
          .where('status', isEqualTo: 'active')
          .get();

      return snapshot.docs
          .map((doc) => StudentEnrollment.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching student enrollments: $e');
      return [];
    }
  }

  Future<StudentEnrollment?> getStudentEnrollment(String enrollmentId) async {
    try {
      final doc = await _db
          .collection('student_enrollments')
          .doc(enrollmentId)
          .get();
      if (doc.exists) {
        return StudentEnrollment.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ Error fetching student enrollment: $e');
      return null;
    }
  }

  Future<void> createStudentEnrollment(StudentEnrollment enrollment) async {
    try {
      await _db
          .collection('student_enrollments')
          .doc(enrollment.id)
          .set(enrollment.toMap());
    } catch (e) {
      print('❌ Error creating student enrollment: $e');
      rethrow;
    }
  }

  Future<void> updateStudentEnrollmentStatus(
    String enrollmentId,
    String status,
  ) async {
    await _db.collection('student_enrollments').doc(enrollmentId).update({
      'status': status,
    });
  }

  // ==================== LECTURER ASSIGNMENTS ====================
  /// Get active teaching assignments for a lecturer
  Future<List<LecturerAssignment>> getLecturerAssignments(
    String lecturerId,
  ) async {
    try {
      final snapshot = await _db
          .collection('lecturer_assignments')
          .where('lecturerId', isEqualTo: lecturerId)
          .where('status', isEqualTo: 'active')
          .get();

      return snapshot.docs
          .map((doc) => LecturerAssignment.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching lecturer assignments: $e');
      return [];
    }
  }

  Future<LecturerAssignment?> getLecturerAssignment(String assignmentId) async {
    try {
      final doc = await _db
          .collection('lecturer_assignments')
          .doc(assignmentId)
          .get();
      if (doc.exists) {
        return LecturerAssignment.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      print('❌ Error fetching lecturer assignment: $e');
      return null;
    }
  }

  Future<void> createLecturerAssignment(LecturerAssignment assignment) async {
    try {
      await _db
          .collection('lecturer_assignments')
          .doc(assignment.id)
          .set(assignment.toMap());
    } catch (e) {
      print('❌ Error creating lecturer assignment: $e');
      rethrow;
    }
  }

  Future<void> updateLecturerAssignmentStatus(
    String assignmentId,
    String status,
  ) async {
    await _db.collection('lecturer_assignments').doc(assignmentId).update({
      'status': status,
    });
  }

  // ==================== UTILITY METHODS ====================
  /// Check if student is enrolled in a specific course
  Future<bool> isStudentEligibleForCourse(
    String studentId,
    String courseId,
  ) async {
    try {
      final snapshot = await _db
          .collection('student_enrollments')
          .where('studentId', isEqualTo: studentId)
          .where('courseId', isEqualTo: courseId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking student eligibility: $e');
      return false;
    }
  }

  /// Check if lecturer is assigned to a specific course
  Future<bool> isLecturerAssignedToCourse(
    String lecturerId,
    String courseId,
  ) async {
    try {
      final snapshot = await _db
          .collection('lecturer_assignments')
          .where('lecturerId', isEqualTo: lecturerId)
          .where('courseId', isEqualTo: courseId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking lecturer assignment: $e');
      return false;
    }
  }

  /// Get all enrollments for a specific course
  Future<List<StudentEnrollment>> getEnrollmentsByCourse(
    String courseId,
  ) async {
    try {
      final snapshot = await _db
          .collection('student_enrollments')
          .where('courseId', isEqualTo: courseId)
          .where('status', isEqualTo: 'active')
          .get();

      return snapshot.docs
          .map((doc) => StudentEnrollment.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error fetching course enrollments: $e');
      return [];
    }
  }
}
