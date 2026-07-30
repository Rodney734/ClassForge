/// Bachelor/Degree programme within an academic field
/// E.g., "Bachelor of Commerce in Business Administration" in "Management, Business & Administration"
class Bachelor {
  final String id;
  final String name; // e.g., "Bachelor of Commerce in Business Administration"
  final String code; // e.g., "BCom BA"
  final String academicFieldId; // Foreign key to academic field
  final String institution;
  final DateTime createdAt;
  final bool isActive;

  Bachelor({
    required this.id,
    required this.name,
    required this.code,
    required this.academicFieldId,
    required this.institution,
    required this.createdAt,
    this.isActive = true,
  });

  factory Bachelor.fromMap(Map<String, dynamic> map) {
    return Bachelor(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      academicFieldId: map['academicFieldId'] ?? '',
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
      'academicFieldId': academicFieldId,
      'institution': institution,
      'createdAt': createdAt,
      'isActive': isActive,
    };
  }
}
