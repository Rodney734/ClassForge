class Course {
  final String id;
  final String name; // e.g., "Business Management", "Accounting Principles"
  final String code; // e.g., "BA101", "ACC102"
  final String description;
  final String academicYearId; // The year this course is offered in
  final String academicFieldId; // The academic field
  final String bachelorId; // The specific degree program
  final List<String> lecturerIds; // Lecturers teaching this course
  final int creditHours;
  final String semester; // e.g., "First", "Second"
  final String institution;
  final DateTime createdAt;
  final bool isActive;

  Course({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.academicYearId,
    required this.academicFieldId,
    required this.bachelorId,
    required this.lecturerIds,
    required this.creditHours,
    required this.semester,
    required this.institution,
    required this.createdAt,
    this.isActive = true,
  });

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      description: map['description'] ?? '',
      academicYearId: map['academicYearId'] ?? '',
      academicFieldId: map['academicFieldId'] ?? '',
      bachelorId: map['bachelorId'] ?? '',
      lecturerIds: List<String>.from(map['lecturerIds'] ?? []),
      creditHours: map['creditHours'] ?? 0,
      semester: map['semester'] ?? 'First',
      institution: map['institution'] ?? 'MAGU',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'academicYearId': academicYearId,
      'academicFieldId': academicFieldId,
      'bachelorId': bachelorId,
      'lecturerIds': lecturerIds,
      'creditHours': creditHours,
      'semester': semester,
      'institution': institution,
      'createdAt': createdAt,
      'isActive': isActive,
    };
  }
}
