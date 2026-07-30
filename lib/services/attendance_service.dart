import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== DEPRECATED: Level-based methods (kept for backward compatibility) ====================

  // Lecturer activates attendance for a class
  Future<void> activateAttendance({
    required String classId,
    required String className,
    required String lecturerId,
    required String lecturerName,
    required int level,
    required Position lecturerLocation,
    required Duration duration,
  }) async {
    final expiryTime = DateTime.now().add(duration);

    await _firestore.collection('active_attendance').doc(classId).set({
      'classId': classId,
      'className': className,
      'lecturerId': lecturerId,
      'lecturerName': lecturerName,
      'level': level,
      'isActive': true,
      'lecturerLatitude': lecturerLocation.latitude,
      'lecturerLongitude': lecturerLocation.longitude,
      'radius': 100, // 100 meters radius
      'startedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiryTime),
      'studentsPresent': [],
      'studentsAbsent': [],
    });
  }

  // Deactivate attendance
  Future<void> deactivateAttendance(String classId) async {
    await _firestore.collection('active_attendance').doc(classId).update({
      'isActive': false,
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  // Student marks attendance
  Future<bool> markAttendance({
    required String classId,
    required String studentId,
    required String studentName,
    required Position studentLocation,
    required double lecturerLat,
    required double lecturerLng,
    required double radius,
  }) async {
    // Calculate distance between lecturer and student
    final distance = _calculateDistance(
      lecturerLat,
      lecturerLng,
      studentLocation.latitude,
      studentLocation.longitude,
    );

    final isWithinRadius = distance <= radius;
    final status = isWithinRadius ? 'present' : 'absent';

    // Record attendance
    final attendanceRef = _firestore.collection('attendance_records').doc();
    await attendanceRef.set({
      'classId': classId,
      'studentId': studentId,
      'studentName': studentName,
      'status': status,
      'distance': distance,
      'studentLatitude': studentLocation.latitude,
      'studentLongitude': studentLocation.longitude,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update active attendance session
    final activeSession = await _firestore
        .collection('active_attendance')
        .doc(classId)
        .get();

    if (activeSession.exists) {
      final data = activeSession.data();
      final studentsPresent = List<String>.from(data?['studentsPresent'] ?? []);
      final studentsAbsent = List<String>.from(data?['studentsAbsent'] ?? []);

      if (status == 'present' && !studentsPresent.contains(studentId)) {
        studentsPresent.add(studentId);
      } else if (status == 'absent' && !studentsAbsent.contains(studentId)) {
        studentsAbsent.add(studentId);
      }

      await _firestore.collection('active_attendance').doc(classId).update({
        'studentsPresent': studentsPresent,
        'studentsAbsent': studentsAbsent,
      });
    }

    return isWithinRadius;
  }

  // Check if attendance is active for a class
  Stream<DocumentSnapshot> getActiveAttendance(String classId) {
    return _firestore.collection('active_attendance').doc(classId).snapshots();
  }

  // Get all active attendance sessions for lecturer
  Stream<QuerySnapshot> getLecturerActiveSessions(String lecturerId) {
    return _firestore
        .collection('active_attendance')
        .where('lecturerId', isEqualTo: lecturerId)
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  // Get attendance records for a class
  Future<List<Map<String, dynamic>>> getAttendanceRecords(
    String classId,
  ) async {
    final snapshot = await _firestore
        .collection('attendance_records')
        .where('classId', isEqualTo: classId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // ==================== NEW: Course-based attendance methods ====================

  /// Lecturer activates attendance for a course
  Future<void> activateAttendanceForCourse({
    required String courseId,
    required String courseName,
    required String lecturerId,
    required String lecturerName,
    required String academicYearId,
    required String academicFieldId,
    required String bachelorId,
    required Position lecturerLocation,
    required Duration duration,
  }) async {
    final expiryTime = DateTime.now().add(duration);
    final sessionId = _firestore.collection('active_attendance').doc().id;

    await _firestore.collection('active_attendance').doc(sessionId).set({
      'sessionId': sessionId,
      'courseId': courseId,
      'courseName': courseName,
      'lecturerId': lecturerId,
      'lecturerName': lecturerName,
      'academicYearId': academicYearId,
      'academicFieldId': academicFieldId,
      'bachelorId': bachelorId,
      'isActive': true,
      'lecturerLatitude': lecturerLocation.latitude,
      'lecturerLongitude': lecturerLocation.longitude,
      'radius': 100, // 100 meters radius
      'startedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiryTime),
      'studentsPresent': [],
      'studentsAbsent': [],
    });
  }

  /// Deactivate course attendance
  Future<void> deactivateCourseAttendance(String sessionId) async {
    await _firestore.collection('active_attendance').doc(sessionId).update({
      'isActive': false,
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Student marks attendance for course
  Future<bool> markCourseAttendance({
    required String sessionId,
    required String courseId,
    required String studentId,
    required String studentName,
    required Position studentLocation,
    required double lecturerLat,
    required double lecturerLng,
    required double radius,
  }) async {
    // Calculate distance between lecturer and student
    final distance = _calculateDistance(
      lecturerLat,
      lecturerLng,
      studentLocation.latitude,
      studentLocation.longitude,
    );

    final isWithinRadius = distance <= radius;
    final status = isWithinRadius ? 'present' : 'absent';

    // Record attendance
    final attendanceRef = _firestore.collection('attendance_records').doc();
    await attendanceRef.set({
      'sessionId': sessionId,
      'courseId': courseId,
      'studentId': studentId,
      'studentName': studentName,
      'status': status,
      'distance': distance,
      'studentLatitude': studentLocation.latitude,
      'studentLongitude': studentLocation.longitude,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update active attendance session
    final activeSession = await _firestore
        .collection('active_attendance')
        .doc(sessionId)
        .get();

    if (activeSession.exists) {
      final data = activeSession.data();
      final studentsPresent = List<String>.from(data?['studentsPresent'] ?? []);
      final studentsAbsent = List<String>.from(data?['studentsAbsent'] ?? []);

      if (status == 'present' && !studentsPresent.contains(studentId)) {
        studentsPresent.add(studentId);
      } else if (status == 'absent' && !studentsAbsent.contains(studentId)) {
        studentsAbsent.add(studentId);
      }

      await _firestore.collection('active_attendance').doc(sessionId).update({
        'studentsPresent': studentsPresent,
        'studentsAbsent': studentsAbsent,
      });
    }

    return isWithinRadius;
  }

  /// Get active attendance sessions for a course
  Stream<QuerySnapshot> getActiveAttendanceByCourse(String courseId) {
    return _firestore
        .collection('active_attendance')
        .where('courseId', isEqualTo: courseId)
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  /// Get attendance records for a course
  Future<List<Map<String, dynamic>>> getCourseAttendanceRecords(
    String courseId,
  ) async {
    final snapshot = await _firestore
        .collection('attendance_records')
        .where('courseId', isEqualTo: courseId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Get attendance records for a specific session
  Future<List<Map<String, dynamic>>> getSessionAttendanceRecords(
    String sessionId,
  ) async {
    final snapshot = await _firestore
        .collection('attendance_records')
        .where('sessionId', isEqualTo: sessionId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Get all active attendance sessions for a lecturer in their courses
  Stream<QuerySnapshot> getLecturerActiveCoursesSessions(String lecturerId) {
    return _firestore
        .collection('active_attendance')
        .where('lecturerId', isEqualTo: lecturerId)
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  // Generate PDF Report
  Future<void> generateAttendancePDF({
    required String className,
    required String lecturerName,
    required DateTime date,
    required List<Map<String, dynamic>> records,
  }) async {
    final pdf = pw.Document();

    final presentStudents = records
        .where((r) => r['status'] == 'present')
        .toList();
    final absentStudents = records
        .where((r) => r['status'] == 'absent')
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Attendance Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text('Class: $className'),
                pw.Text('Lecturer: $lecturerName'),
                pw.Text('Date: ${date.day}/${date.month}/${date.year}'),
                pw.Text(
                  'Time: ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                ),
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: pw.EdgeInsets.all(10),
                  color: PdfColors.green100,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Total Students: ${records.length}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Present: ${presentStudents.length}',
                        style: pw.TextStyle(color: PdfColors.green),
                      ),
                      pw.Text(
                        'Absent: ${absentStudents.length}',
                        style: pw.TextStyle(color: PdfColors.red),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
              ],
            ),
          ),
          pw.Table.fromTextArray(
            headers: [
              'No.',
              'Student Name',
              'Status',
              'Distance (m)',
              'Timestamp',
            ],
            data: List.generate(records.length, (index) {
              final record = records[index];
              final timestamp = (record['timestamp'] as Timestamp).toDate();
              return [
                (index + 1).toString(),
                record['studentName'] ?? 'Unknown',
                record['status'] == 'present' ? '✓ Present' : '✗ Absent',
                record['distance']?.toStringAsFixed(2) ?? 'N/A',
                '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
              ];
            }),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );

    // Save and print
    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/attendance_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());

    // Open the file
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'attendance_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  // Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double R = 6371000; // Earth radius in meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) *
            _cos(_toRadians(lat2)) *
            _sin(dLon / 2) *
            _sin(dLon / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) => degree * (3.141592653589793 / 180);
  double _sin(double x) => math.sin(x);
  double _cos(double x) => math.cos(x);
  double _sqrt(double x) => math.sqrt(x);
  double _atan2(double y, double x) => math.atan2(y, x);
}
