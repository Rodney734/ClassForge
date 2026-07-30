class AppUser {
  final String uid;
  final String fullName;
  final String email;
  final String role; // 'student' or 'lecturer'
  final int level; // Kept for backward compatibility (1-4)

  // Student-specific permanent registration fields
  final String? studentId;
  final String? academicYearId; // Student's permanent academic year
  final String? academicFieldId; // Student's permanent academic field
  final String? bachelorId; // Student's permanent bachelor/degree

  // Lecturer-specific fields
  final String? lecturerCode;
  final List<String> teachingYearIds; // Years lecturer teaches (lecturers only)

  // Active course context (for both student and lecturer)
  // This is NOT the same as permanent registration - it's the currently selected course
  final String? activeModuleId;
  final String? activeModuleName;
  final String? activeCourseId;
  final String? activeCourseName;

  // General fields
  final int streak;
  final String? profilePicture;
  final String? bio;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    required this.level,
    this.streak = 0,
    this.studentId,
    this.academicYearId,
    this.academicFieldId,
    this.bachelorId,
    this.lecturerCode,
    this.teachingYearIds = const [],
    this.activeModuleId,
    this.activeModuleName,
    this.activeCourseId,
    this.activeCourseName,
    this.profilePicture,
    this.bio,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  static DateTime _dateTimeFromDynamic(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    if (value != null && value.toString().contains('Timestamp')) {
      return (value as dynamic).toDate();
    }
    return DateTime.now();
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'student',
      level: map['level'] ?? 4,
      streak: map['streak'] ?? 0,
      studentId: map['studentId'],
      academicYearId: map['academicYearId'],
      academicFieldId: map['academicFieldId'],
      bachelorId: map['bachelorId'],
      lecturerCode: map['lecturerCode'],
      teachingYearIds: List<String>.from(map['teachingYearIds'] ?? []),
      activeModuleId: map['activeModuleId'],
      activeModuleName: map['activeModuleName'],
      activeCourseId: map['activeCourseId'],
      activeCourseName: map['activeCourseName'],
      profilePicture: map['profilePicture'],
      bio: map['bio'],
      createdAt: _dateTimeFromDynamic(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap({bool forCache = false}) {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'role': role,
      'level': level,
      'streak': streak,
      'studentId': studentId,
      'academicYearId': academicYearId,
      'academicFieldId': academicFieldId,
      'bachelorId': bachelorId,
      'lecturerCode': lecturerCode,
      'teachingYearIds': teachingYearIds,
      'activeModuleId': activeModuleId,
      'activeModuleName': activeModuleName,
      'activeCourseId': activeCourseId,
      'activeCourseName': activeCourseName,
      'profilePicture': profilePicture,
      'bio': bio,
      'createdAt': forCache ? createdAt.toUtc().toIso8601String() : createdAt,
    };
  }

  // Helper method to create a copy with updated active course
  AppUser copyWithActiveModule({
    required String moduleId,
    required String moduleName,
    required String courseId,
    required String courseName,
  }) {
    return AppUser(
      uid: uid,
      fullName: fullName,
      email: email,
      role: role,
      level: level,
      streak: streak,
      studentId: studentId,
      academicYearId: academicYearId,
      academicFieldId: academicFieldId,
      bachelorId: bachelorId,
      lecturerCode: lecturerCode,
      teachingYearIds: teachingYearIds,
      activeModuleId: moduleId,
      activeModuleName: moduleName,
      activeCourseId: courseId,
      activeCourseName: courseName,
      profilePicture: profilePicture,
      bio: bio,
      createdAt: createdAt,
    );
  }
}
