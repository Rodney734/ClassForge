import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';
import 'student_id_service.dart';
import 'lecturer_code_service.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestore = FirestoreService();
  final LecturerCodeService _lecturerCodeService = LecturerCodeService();

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  AuthService() {
    _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        // User is logged in, load their profile from Firestore.
        try {
          _currentUser = await _firestore.getUser(firebaseUser.uid);
          print(
            "✅ User loaded: ${_currentUser?.fullName} - Role: ${_currentUser?.role}",
          );
        } catch (e) {
          print("⚠️ Auth failed to load Firestore profile: $e");
          _currentUser = null;
        }
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      print("🔑 Login successful for: $email");
      return null;
    } on FirebaseAuthException catch (e) {
      print("❌ Login failed: $e");
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        return 'Incorrect email or password. Please try again.';
      } else if (e.code == 'wrong-password') {
        return 'Incorrect password. Please try again.';
      } else if (e.code == 'too-many-requests') {
        return 'Too many failed attempts. Please try again later.';
      }
      return e.message ?? 'Login failed. Please try again.';
    } catch (e) {
      print("❌ Login failed: $e");
      return e.toString();
    }
  }

  // Register (keep as it is)
  Future<String?> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    required int level,
    String? studentId,
    String? lecturerCode,
  }) async {
    try {
      // --- Lecturer Registration with Code ---
      if (role.toLowerCase() == 'lecturer') {
        if (lecturerCode == null || lecturerCode.isEmpty) {
          return 'Lecturer registration code is required.';
        }

        // Use a transaction to safely check and update the lecturer code
        return await FirebaseFirestore.instance.runTransaction<String?>((
          transaction,
        ) async {
          final codeQuery = await FirebaseFirestore.instance
              .collection('lecturer_codes')
              .where('code', isEqualTo: lecturerCode)
              .limit(1)
              .get();

          if (codeQuery.docs.isEmpty) {
            return 'Invalid lecturer registration code.';
          }

          final codeDoc = codeQuery.docs.first;
          if (codeDoc.data()['used'] == true) {
            return 'This lecturer registration code has already been used.';
          }

          // Code is valid, proceed to create user
          final userCredential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          final user = userCredential.user!;

          // Update the code document
          transaction.update(codeDoc.reference, {
            'used': true,
            'usedBy': user.uid,
            'usedAt': FieldValue.serverTimestamp(),
          });

          // Return the new user's UID to be used outside the transaction
          return user.uid;
        });
      }

      // --- Student Registration with ID (existing logic) ---
      if (role.toLowerCase() == 'student') {
        if (studentId == null || studentId.isEmpty) {
          return 'Student ID is required';
        }
        final studentIdService = StudentIdService();
        final isValid = await studentIdService.isValidStudentId(studentId);
        if (!isValid) {
          return 'Invalid Student ID. Please contact your lecturer.';
        }
      }

      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      AppUser newUser = AppUser(
        uid: result.user!.uid,
        fullName: fullName,
        email: email,
        role: role.toLowerCase(), // Force lowercase
        level: level,
      );

      await _firestore.saveUser(newUser);

      print("✅ Registered: $fullName as $role. User can now log in directly.");
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return 'This email is already registered. Please login instead.';
      }
      return e.message ?? 'Registration failed. Please try again.';
    } catch (e) {
      print("❌ Registration failed: $e");
      return e.toString();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> updateProfilePicture(String base64Image) async {
    if (_currentUser == null) return;
    try {
      // Update the user document in Firestore with the Base64 string
      await _firestore.updateUserProfile(_currentUser!.uid, {
        'profilePicture': base64Image,
      });
      // Refresh the local user data
      _currentUser = await _firestore.getUser(_currentUser!.uid);
      notifyListeners();
    } catch (e) {
      print("❌ Upload failed: $e");
      rethrow;
    }
  }

  Future<void> updateBackgroundImage(String base64Image) async {
    if (_currentUser == null) return;
    try {
      // Update the user document in Firestore with the Base64 string
      await _firestore.updateUserProfile(_currentUser!.uid, {
        'backgroundImage': base64Image,
      });
      // Refresh the local user data
      _currentUser = await _firestore.getUser(_currentUser!.uid);
      notifyListeners();
    } catch (e) {
      print("❌ Background image upload failed: $e");
      rethrow;
    }
  }

  Future<void> updateUserProfile({
    required String fullName,
    required String bio,
  }) async {
    if (_currentUser != null) {
      await _firestore.updateUserProfile(_currentUser!.uid, {
        'fullName': fullName,
        'bio': bio,
      });
      // Refresh local user data
      _currentUser = await _firestore.getUser(_currentUser!.uid);
      notifyListeners();
    }
  }
}
