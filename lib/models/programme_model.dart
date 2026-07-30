class Programme {
  final String id;
  final String name; // e.g., "Agriculture", "Biomedicine", "Biotechnology"
  final String code; // e.g., "AGR", "BIO"
  final String description;
  final List<String> academicYearIds; // Years this programme is offered
  final String institution;
  final DateTime createdAt;
  final bool isActive;

  Programme({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    required this.academicYearIds,
    required this.institution,
    required this.createdAt,
    this.isActive = true,
  });

  factory Programme.fromMap(Map<String, dynamic> map) {
    return Programme(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      code: map['code'] ?? '',
      description: map['description'] ?? '',
      academicYearIds: List<String>.from(map['academicYearIds'] ?? []),
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
      'academicYearIds': academicYearIds,
      'institution': institution,
      'createdAt': createdAt,
      'isActive': isActive,
    };
  }
}
