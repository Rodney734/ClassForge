class LecturerAssignment {
  final String id;
  final String lecturerId; // FK to user
  final String courseId; // FK to course
  final String academicYearId;
  final String academicFieldId;
  final String bachelorId;
  final DateTime assignedAt;
  final String status; // "active", "completed", "inactive"
  final DateTime? startDate;
  final DateTime? endDate;

  LecturerAssignment({
    required this.id,
    required this.lecturerId,
    required this.courseId,
    required this.academicYearId,
    required this.academicFieldId,
    required this.bachelorId,
    required this.assignedAt,
    this.status = 'active',
    this.startDate,
    this.endDate,
  });

  factory LecturerAssignment.fromMap(Map<String, dynamic> map) {
    return LecturerAssignment(
      id: map['id'] ?? '',
      lecturerId: map['lecturerId'] ?? '',
      courseId: map['courseId'] ?? '',
      academicYearId: map['academicYearId'] ?? '',
      academicFieldId: map['academicFieldId'] ?? '',
      bachelorId: map['bachelorId'] ?? '',
      assignedAt: (map['assignedAt'] as dynamic)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'active',
      startDate: (map['startDate'] as dynamic)?.toDate(),
      endDate: (map['endDate'] as dynamic)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lecturerId': lecturerId,
      'courseId': courseId,
      'academicYearId': academicYearId,
      'academicFieldId': academicFieldId,
      'bachelorId': bachelorId,
      'assignedAt': assignedAt,
      'status': status,
      'startDate': startDate,
      'endDate': endDate,
    };
  }
}
