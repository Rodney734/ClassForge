/// Represents an academic field/faculty
/// E.g., "Management, Business & Administration", "Computing, Mathematics & ICT"
class AcademicField {
  final String id;
  final String name; // e.g., "Management, Business & Administration"
  final String code; // e.g., "MBA", "CM"
  final String description;
  final String institution;
  final DateTime createdAt;
  final bool isActive;

  AcademicField({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.institution,
    required this.createdAt,
    this.isActive = true,
  });

  factory AcademicField.fromMap(Map<String, dynamic> map) {
    return AcademicField(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      description: map['description'] ?? '',
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
      'institution': institution,
      'createdAt': createdAt,
      'isActive': isActive,
    };
  }
}
