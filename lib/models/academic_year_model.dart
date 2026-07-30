class AcademicYear {
  final String id;
  final String name; // e.g., "First Year", "Year 1", "Year 2"
  final int level; // 1-4 for undergraduate
  final String institution; // e.g., "MAGU"
  final DateTime createdAt;
  final bool isActive;

  AcademicYear({
    required this.id,
    required this.name,
    required this.level,
    required this.institution,
    required this.createdAt,
    this.isActive = true,
  });

  factory AcademicYear.fromMap(Map<String, dynamic> map) {
    return AcademicYear(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      level: map['level'] ?? 1,
      institution: map['institution'] ?? 'MAGU',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'level': level,
      'institution': institution,
      'createdAt': createdAt,
      'isActive': isActive,
    };
  }
}
