import 'dart:convert';

import 'package:classforge/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiCallableException implements Exception {
  final String code;
  final String message;

  const AiCallableException({required this.code, required this.message});
}

class AITutorService {
  static const String _functionsRegion = 'us-central1';
  static const String _functionsEmulatorHost = '127.0.0.1';
  static const int _functionsEmulatorPort = 5001;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: _functionsRegion,
  );

  bool get _useFunctionsEmulator =>
      kDebugMode && defaultTargetPlatform == TargetPlatform.windows;

  Future<Map<String, dynamic>> _callFunction(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return _callWindowsFunction(name, data);
    }

    final callable = _functions.httpsCallable(name);
    final result = await callable.call<Map<String, dynamic>>(data);
    return Map<String, dynamic>.from(result.data);
  }

  Future<Map<String, dynamic>> _callWindowsFunction(
    String name,
    Map<String, dynamic> data,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();
    if (idToken == null) {
      throw const AiCallableException(
        code: 'unauthenticated',
        message: 'Please sign in again to use the AI tutor.',
      );
    }

    final projectId = Firebase.app().options.projectId;
    final uri = _useFunctionsEmulator
        ? Uri.http(
            '$_functionsEmulatorHost:$_functionsEmulatorPort',
            '/$projectId/$_functionsRegion/$name',
          )
        : Uri.https('$_functionsRegion-$projectId.cloudfunctions.net', name);

    late final http.Response response;
    try {
      response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({'data': data}),
      );
    } on http.ClientException {
      if (_useFunctionsEmulator) {
        throw const AiCallableException(
          code: 'unavailable',
          message:
              'The local Firebase Functions emulator is not running. Start it with `firebase emulators:start --only functions --project classforge-app`.',
        );
      }
      rethrow;
    }

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (!contentType.contains('application/json')) {
      if (response.statusCode == 404) {
        throw AiCallableException(
          code: 'not-found',
          message: _useFunctionsEmulator
              ? 'The local Firebase Functions emulator did not register `$name`. Check its startup logs.'
              : 'The AI function is not deployed in $_functionsRegion for project $projectId.',
        );
      }

      throw AiCallableException(
        code: response.statusCode.toString(),
        message:
            'The AI service returned a non-JSON response (HTTP ${response.statusCode}).',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw AiCallableException(
        code: 'invalid-response',
        message:
            'The AI service returned invalid JSON (HTTP ${response.statusCode}).',
      );
    }
    if (decoded is! Map) {
      throw const AiCallableException(
        code: 'internal',
        message: 'The AI service returned an invalid response.',
      );
    }

    final error = decoded['error'];
    if (error is Map) {
      throw AiCallableException(
        code: error['status']?.toString() ?? 'unknown',
        message: error['message']?.toString() ?? 'The AI request failed.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiCallableException(
        code: response.statusCode.toString(),
        message: 'The AI service returned HTTP ${response.statusCode}.',
      );
    }

    final result = decoded['result'] ?? decoded['response'] ?? decoded['data'];
    if (result is! Map) {
      throw const AiCallableException(
        code: 'internal',
        message: 'The AI service returned an invalid response.',
      );
    }
    return Map<String, dynamic>.from(result);
  }

  // Send a message to the secure backend.
  Future<void> sendMessage({
    required String message,
    required String userId,
  }) async {
    final userSnapshot = await _firestore.collection('users').doc(userId).get();
    final user = AppUser.fromMap(userSnapshot.data()!);

    await _callFunction('aiTutor', {
      'message': message,
      'userId': userId,
      'level': user.level,
    });
  }

  Stream<QuerySnapshot> getChatStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('ai_tutor_messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
}
