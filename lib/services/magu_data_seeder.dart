import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/academic_year_model.dart';
import '../models/academic_field_model.dart';
import '../models/bachelor_model.dart';

/// Service to initialize MAGU academic structure in Firestore
/// Based on official MAGU undergraduate programmes and hierarchy:
/// Academic Field → Bachelor/Programme → Modules/Courses
class MAGUDataSeeder {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String INSTITUTION = 'MAGU';

  /// Initialize MAGU academic structure in Firestore
  /// This should be called once during app setup or admin initialization
  Future<void> initializeMAGUStructure() async {
    try {
      print("🔄 Initializing MAGU academic structure...");

      // Create Academic Years
      await _createAcademicYears();

      // Create Academic Fields
      final fieldIds = await _createAcademicFields();

      // Create Bachelor Programmes (within fields)
      await _createBachelors(fieldIds);

      // Existing course documents are preserved. Course/module data can be
      // added separately for each programme once the official curricula are
      // available.

      print("✅ MAGU academic structure initialized successfully!");
    } catch (e) {
      print("❌ Error initializing MAGU structure: $e");
      rethrow;
    }
  }

  /// Create MAGU academic years (1st, 2nd, 3rd, 4th Year)
  Future<void> _createAcademicYears() async {
    print("📚 Creating academic years...");
    final years = {
      'First Year': 1,
      'Second Year': 2,
      'Third Year': 3,
      'Fourth Year': 4,
    };

    for (final entry in years.entries) {
      final existing = await _db
          .collection('academic_years')
          .where('institution', isEqualTo: INSTITUTION)
          .where('name', isEqualTo: entry.key)
          .limit(1)
          .get();
      final yearId = existing.docs.isNotEmpty
          ? existing.docs.first.id
          : _db.collection('academic_years').doc().id;
      final year = AcademicYear(
        id: yearId,
        name: entry.key,
        level: entry.value,
        institution: INSTITUTION,
        createdAt: DateTime.now(),
        isActive: true,
      );

      await _db
          .collection('academic_years')
          .doc(yearId)
          .set(year.toMap(), SetOptions(merge: true));
      print("  ✓ Created: ${entry.key}");
    }
  }

  /// Create MAGU academic fields/faculties
  /// Based on official MAGU structure
  Future<Map<String, String>> _createAcademicFields() async {
    print("🏫 Creating academic fields...");

    final fields = [
      {
        'name': 'Faculty of Commerce & Management',
        'code': 'FCM',
        'description': 'Faculty of Commerce and Management',
      },
      {
        'name': 'Faculty of Education',
        'code': 'FED',
        'description': 'Faculty of Education',
      },
      {
        'name': 'Faculty of Social Science and Ministerial Formation',
        'code': 'FSSMF',
        'description': 'Faculty of Social Science and Ministerial Formation',
      },
      {
        'name': 'Department of Theology',
        'code': 'DOT',
        'description': 'Department of Theology',
      },
    ];

    final Map<String, String> fieldIds = {};
    final currentCodes = fields.map((field) => field['code']).toSet();
    final existingFields = await _db
        .collection('academic_fields')
        .where('institution', isEqualTo: INSTITUTION)
        .get();
    for (final document in existingFields.docs) {
      if (!currentCodes.contains(document.data()['code'])) {
        await document.reference.update({'isActive': false});
      }
    }

    for (final field in fields) {
      final existing = await _db
          .collection('academic_fields')
          .where('institution', isEqualTo: INSTITUTION)
          .where('code', isEqualTo: field['code'])
          .limit(1)
          .get();
      final fieldId = existing.docs.isNotEmpty
          ? existing.docs.first.id
          : _db.collection('academic_fields').doc().id;
      final fieldObj = AcademicField(
        id: fieldId,
        name: field['name'] as String,
        code: field['code'] as String,
        description: field['description'] as String,
        institution: INSTITUTION,
        createdAt: DateTime.now(),
        isActive: true,
      );

      await _db
          .collection('academic_fields')
          .doc(fieldId)
          .set(fieldObj.toMap(), SetOptions(merge: true));
      fieldIds[field['code'] as String] = fieldId;
      print("  ✓ Created: ${field['name']}");
    }

    return fieldIds;
  }

  /// Create MAGU bachelor programmes within their fields
  Future<void> _createBachelors(Map<String, String> fieldIds) async {
    print("🎓 Creating bachelor programmes...");

    final bachelors = [
      // Faculty of Commerce & Management
      {'name': 'Bachelor of Accountancy', 'code': 'BACC', 'field': 'FCM'},
      {
        'name': 'Bachelor of Commerce - Accounting',
        'code': 'BCOM-ACC',
        'field': 'FCM',
      },
      {
        'name': 'Bachelor of Commerce - Banking and Finance',
        'code': 'BCOM-BF',
        'field': 'FCM',
      },
      {
        'name': 'Bachelor of Commerce - Business Administration',
        'code': 'BCOM-BA',
        'field': 'FCM',
      },
      {
        'name': 'Bachelor of Commerce - Human Resource Management',
        'code': 'BCOM-HRM',
        'field': 'FCM',
      },
      {
        'name': 'Bachelor of Commerce - Insurance',
        'code': 'BCOM-INS',
        'field': 'FCM',
      },
      {
        'name': 'Bachelor of Commerce - Marketing',
        'code': 'BCOM-MKT',
        'field': 'FCM',
      },
      {
        'name': 'Bachelor of Commerce - Monitoring and Evaluation',
        'code': 'BCOM-ME',
        'field': 'FCM',
      },
      {
        'name': 'Bachelor of Science in Business Information Systems',
        'code': 'BSC-BIS',
        'field': 'FCM',
      },

      // Faculty of Education
      {
        'name': 'Bachelor of Arts Education (Literature and Linguistics)',
        'code': 'BAED-LL',
        'field': 'FED',
      },
      {
        'name':
            'Bachelor of Education Science (Mathematics and Computer Studies)',
        'code': 'BED-SCI',
        'field': 'FED',
      },
      {
        'name': 'Bachelor of Education (History & Social Studies)',
        'code': 'BED-HSS',
        'field': 'FED',
      },
      {
        'name': 'University Certificate of Education (UCE)',
        'code': 'UCE',
        'field': 'FED',
      },

      // Faculty of Social Science and Ministerial Formation
      {
        'name': 'Bachelor of Social Science in Community Development',
        'code': 'BSS-CD',
        'field': 'FSSMF',
      },
      {
        'name': 'Bachelor of Social Science in Early Childhood Development',
        'code': 'BSS-ECD',
        'field': 'FSSMF',
      },
      {
        'name': 'Bachelor of Social Science in Social Work',
        'code': 'BSS-SW',
        'field': 'FSSMF',
      },
      {
        'name': 'Diploma in Early Childhood Development',
        'code': 'DIP-ECD',
        'field': 'FSSMF',
      },
      {'name': 'Diploma in Social Work', 'code': 'DIP-SW', 'field': 'FSSMF'},

      // Department of Theology
      {
        'name': 'Bachelor of Arts Biblical Studies',
        'code': 'BA-BS',
        'field': 'DOT',
      },
      {
        'name': 'Bachelor of Arts in Community Counselling',
        'code': 'BA-CC',
        'field': 'DOT',
      },
      {
        'name': 'Bachelor of Arts in Intercultural Studies',
        'code': 'BA-IS',
        'field': 'DOT',
      },
      {
        'name': 'Bachelor of Arts in Religious Education Ministries',
        'code': 'BA-REM',
        'field': 'DOT',
      },
    ];

    final currentCodes = bachelors.map((item) => item['code']).toSet();
    final existingBachelors = await _db
        .collection('bachelors')
        .where('institution', isEqualTo: INSTITUTION)
        .get();
    for (final document in existingBachelors.docs) {
      if (!currentCodes.contains(document.data()['code'])) {
        await document.reference.update({'isActive': false});
      }
    }

    for (final bach in bachelors) {
      final fieldKey = bach['field'] as String;
      final fieldId = fieldIds[fieldKey] ?? '';
      final existing = await _db
          .collection('bachelors')
          .where('institution', isEqualTo: INSTITUTION)
          .where('code', isEqualTo: bach['code'])
          .limit(1)
          .get();
      final bachelorId = existing.docs.isNotEmpty
          ? existing.docs.first.id
          : _db.collection('bachelors').doc().id;

      final bachelor = Bachelor(
        id: bachelorId,
        name: bach['name'] as String,
        code: bach['code'] as String,
        academicFieldId: fieldId,
        institution: INSTITUTION,
        createdAt: DateTime.now(),
        isActive: true,
      );

      await _db
          .collection('bachelors')
          .doc(bachelorId)
          .set(bachelor.toMap(), SetOptions(merge: true));
      print("  ✓ Created: ${bach['name']}");
    }
  }
}
