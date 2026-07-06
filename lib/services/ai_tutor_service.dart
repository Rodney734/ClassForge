import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AITutorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // System prompt
  static const String SYSTEM_PROMPT = '''
You are ClassForge AI, an educational tutor for university students.

Your purpose is to help students learn academic subjects including:
- Programming (Flutter, Dart, Python, Java, C++, JavaScript, etc.)
- Databases (SQL, MongoDB, Firebase)
- Artificial Intelligence, Machine Learning
- Networking, Cybersecurity, Software Engineering
- Mathematics, Physics, Chemistry, Biology
- Business Studies, Accounting, Economics
- Any other academic discipline

BEHAVIOR GUIDELINES:
1. Be patient, encouraging, and professional like a good teacher
2. Explain concepts step by step with clear examples
3. Ask guiding questions to encourage critical thinking
4. Give hints instead of immediately revealing answers
5. Adapt explanations based on the student's level
6. When appropriate, generate practice questions or mini-quizzes

RESPONSE FORMAT:
- Keep responses clear and well-structured
- Use bullet points for lists
- Provide examples where helpful
- For complex topics, break down into smaller parts

OUT OF SCOPE - Politely decline:
- Dating advice, relationships, therapy, mental health counselling
- Politics, gossip, celebrity news, entertainment
- Illegal activities, non-educational conversations

Redirect with: "I'm ClassForge AI. My purpose is to help students with educational and academic learning. Please ask me a question related to your studies."
''';

  // Send a message to Mistral AI
  Future<void> sendMessage({
    required String message,
    required String userId,
  }) async {
    // Save the user's message to Firestore first for a responsive UI.
    await _saveMessage(userId: userId, text: message, isUser: true);

    try {
      // Get user level to pass to the function
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userLevel = userDoc.data()?['level'] ?? 1;

      // Call the Cloud Function. It will handle the AI API call and save the response.
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'aiTutor',
      );
      await callable.call({
        'message': message,
        'userId': userId,
        'level': userLevel,
      });
    } on FirebaseFunctionsException catch (e) {
      // If the function fails, save an error message to the chat UI.
      await _saveMessage(
        userId: userId,
        text: 'Error: ${e.message}',
        isUser: false,
      );
    } catch (e) {
      // Handle other potential errors.
      await _saveMessage(
        userId: userId,
        text: 'An unexpected error occurred: $e',
        isUser: false,
      );
    }
  }

  // Save message to Firestore
  Future<void> _saveMessage({
    required String userId,
    required String text,
    required bool isUser,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('ai_tutor_messages')
        .add({
          'text': text,
          'isUser': isUser,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  // Get chat stream for a user
  Stream<QuerySnapshot> getChatStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('ai_tutor_messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
}
