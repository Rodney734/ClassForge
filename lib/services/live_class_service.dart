import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class LiveClassService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Starts a live class for a specific level.
  /// Creates or updates a document in 'scheduled_classes' with status 'live'.
  Future<void> startLiveClass({
    required int level,
    required String className,
    required String lecturerId,
    required String lecturerName,
  }) async {
    final classDocRef = _firestore
        .collection('scheduled_classes')
        .doc('live_class_level_$level');

    await classDocRef.set({
      'courseName': className,
      'level': level,
      'lecturerId': lecturerId,
      'lecturerName': lecturerName,
      'status': 'live',
      'startedAt': FieldValue.serverTimestamp(),
      'endedAt': null, // Ensure it's null when starting
      'participants': [], // Initialize participants list
      'chatMessages': [],
      'reactions': [],
    }, SetOptions(merge: true)); // Use merge to update if exists, create if not
  }

  /// Ends a live class for a specific level.
  /// Updates the document in 'scheduled_classes' to status 'closed'.
  Future<void> endLiveClass({required int level}) async {
    final classDocRef = _firestore
        .collection('scheduled_classes')
        .doc('live_class_level_$level');

    await classDocRef.update({
      'status': 'closed',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Gets a stream of the live class status for a specific level.
  Stream<DocumentSnapshot> getLiveClassStatus(int level) {
    return _firestore
        .collection('scheduled_classes')
        .doc('live_class_level_$level')
        .snapshots();
  }

  /// Fetches the live class data (chat messages, reactions) for a specific level.
  Future<Map<String, dynamic>> getLiveClassData(int level) async {
    final classDoc = await _firestore
        .collection('scheduled_classes')
        .doc('live_class_level_$level')
        .get();

    if (classDoc.exists) {
      final data = classDoc.data() ?? <String, dynamic>{};
      return {
        'chatMessages': data['chatMessages'] ?? <Map<String, dynamic>>[],
        'reactions': data['reactions'] ?? <Map<String, dynamic>>[],
      };
    }
    return {'chatMessages': [], 'reactions': []};
  }

  /// Adds a student to the participants list of a live class.
  Future<void> joinClass({
    required int level,
    required String studentId,
    required String studentName,
  }) async {
    final classDocRef = _firestore
        .collection('scheduled_classes')
        .doc('live_class_level_$level');

    await classDocRef.update({
      'participants': FieldValue.arrayUnion([
        {'id': studentId, 'name': studentName, 'joinedAt': Timestamp.now()},
      ]),
    });
  }

  /// Removes a student from the participants list of a live class.
  Future<void> leaveClass({required int level, required String userId}) async {
    final classDocRef = _firestore
        .collection('scheduled_classes')
        .doc('live_class_level_$level');

    // To remove an item from an array, you need to provide the exact item.
    // This requires fetching the document first to find the matching participant entry.
    final docSnapshot = await classDocRef.get();
    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      if (data != null && data['participants'] is List) {
        final participants = List<Map<String, dynamic>>.from(
          data['participants'],
        );
        final participantToRemove = participants.firstWhere(
          (p) => p['id'] == userId,
          orElse: () => {}, // Return an empty map if not found
        );

        if (participantToRemove.isNotEmpty) {
          await classDocRef.update({
            'participants': FieldValue.arrayRemove([participantToRemove]),
          });
        }
      }
    }
  }

  /// Sends a chat message to the live class.
  Future<void> sendChatMessage({
    required int level,
    required String message,
    required String userId,
    required String userName,
  }) async {
    final classDocRef = _firestore
        .collection('scheduled_classes')
        .doc('live_class_level_$level');

    await classDocRef.update({
      'chatMessages': FieldValue.arrayUnion([
        {
          'message': message,
          'userName': userName,
          'userId': userId,
          'timestamp': Timestamp.now(),
        },
      ]),
    });
  }

  /// Sends a reaction to the live class.
  Future<void> sendReaction({
    required int level,
    required String reaction,
    required String userId,
    required String userName,
  }) async {
    final classDocRef = _firestore
        .collection('scheduled_classes')
        .doc('live_class_level_$level');
    const uuid = Uuid();
    await classDocRef.update({
      'reactions': FieldValue.arrayUnion([
        {
          'id': uuid.v4(),
          'reaction': reaction,
          'userId': userId,
          'userName': userName,
          'timestamp': Timestamp.now(),
        },
      ]),
    });
  }
}
