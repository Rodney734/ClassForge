class AppUser {
  final String uid;
  final String fullName;
  final String email;
  final String role;
  final int level;
  final String? studentId;
  final int streak;
  final String? profilePicture;

  AppUser({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    required this.level,
    this.streak = 0,
    this.studentId,
    this.profilePicture,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'student',
      level: map['level'] ?? 4,
      streak: map['streak'] ?? 0,
      profilePicture: map['profilePicture'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'role': role,
      'level': level,
      'streak': streak,
      'profilePicture': profilePicture,
    };
  }
}
