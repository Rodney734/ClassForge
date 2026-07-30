class StudentEnrollment {
  final String id;
  final String studentId; // FK to user
  final String courseId; // FK to course
  final String academicYearId;
  final String academicFieldId;
  final String bachelorId;
  final DateTime enrolledAt;
  final String status; // "active", "completed", "dropped"
  final double? grade;
  final DateTime? completedAt;

  StudentEnrollment({
    required this.id,
    required this.studentId,
    required this.courseId,
    required this.academicYearId,
    required this.academicFieldId,
    required this.bachelorId,
    required this.enrolledAt,
    this.status = 'active',
    this.grade,
    this.completedAt,
  });

  factory StudentEnrollment.fromMap(Map<String, dynamic> map) {
    return StudentEnrollment(
      id: map['id'] ?? '',
      studentId: map['studentId'] ?? '',
      courseId: map['courseId'] ?? '',
      academicYearId: map['academicYearId'] ?? '',
      academicFieldId: map['academicFieldId'] ?? '',
      bachelorId: map['bachelorId'] ?? '',
      enrolledAt: (map['enrolledAt'] as dynamic)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'active',
      grade: map['grade']?.toDouble(),
      completedAt: (map['completedAt'] as dynamic)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'courseId': courseId,
      'academicYearId': academicYearId,
      'academicFieldId': academicFieldId,
      'bachelorId': bachelorId,
      'enrolledAt': enrolledAt,
      'status': status,
      'grade': grade,
      'completedAt': completedAt,
    };
  }
}
