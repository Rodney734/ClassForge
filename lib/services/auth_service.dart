import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../models/user_model.dart';
import 'firestore_service.dart';
import 'offline_sync_service.dart';
import 'student_id_service.dart';
import 'lecturer_code_service.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestore = FirestoreService();
  final LecturerCodeService _lecturerCodeService = LecturerCodeService();

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool _isLoadingProfile = true;
  bool get isLoadingProfile => _isLoadingProfile;

  AuthService() {
    _auth.authStateChanges().listen((User? firebaseUser) async {
      _isLoadingProfile = true;
      notifyListeners();

      if (firebaseUser != null) {
        await _loadUserProfile(firebaseUser);
      } else {
        _currentUser = null;
      }
      _isLoadingProfile = false;
      notifyListeners();
    });
  }

  Future<void> _loadUserProfile(User firebaseUser) async {
    try {
      _currentUser = await _firestore.getUser(firebaseUser.uid);
      if (_currentUser != null) {
        await OfflineSyncService.cacheUserProfile(_currentUser!);
      }
      print(
        "✅ User loaded: ${_currentUser?.fullName} - Role: ${_currentUser?.role}",
      );
    } catch (e) {
      print("⚠️ Auth failed to load Firestore profile: $e");
      _currentUser = await OfflineSyncService.getCachedUserProfile();
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        return 'Login failed. Please try again.';
      }

      _isLoadingProfile = true;
      notifyListeners();
      await _loadUserProfile(firebaseUser);
      _isLoadingProfile = false;
      notifyListeners();

      if (_currentUser == null) {
        return 'Your account profile could not be loaded. Please try again.';
      }

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
    } finally {
      _isLoadingProfile = false;
    }
  }

  // Register (Updated to support new academic structure)
  Future<String?> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    required int level,
    // Academic context selected during registration.
    String? studentId,
    String? academicYearId,
    String? academicFieldId,
    String? bachelorId,
    // Lecturer registration fields
    String? lecturerCode,
    List<String> teachingYearIds = const [],
  }) async {
    try {
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

      // Consume lecturer codes only after Firebase Auth has created the user,
      // because the Firestore rule requires an authenticated request.
      if (role.toLowerCase() == 'lecturer') {
        if (lecturerCode == null || lecturerCode.isEmpty) {
          await result.user?.delete();
          return 'Lecturer registration code is required.';
        }
        final isCodeValid = await _lecturerCodeService.validateAndUseCode(
          lecturerCode,
        );
        if (!isCodeValid) {
          await result.user?.delete();
          return 'Invalid or already used lecturer registration code.';
        }
      }

      AppUser newUser = AppUser(
        uid: result.user!.uid,
        fullName: fullName,
        email: email,
        role: role.toLowerCase(), // Force lowercase
        level: level,
        studentId: role.toLowerCase() == 'student' ? studentId : null,
        academicYearId: academicYearId,
        academicFieldId: academicFieldId,
        bachelorId: bachelorId,
        lecturerCode: role.toLowerCase() == 'lecturer' ? lecturerCode : null,
        teachingYearIds: role.toLowerCase() == 'lecturer'
            ? teachingYearIds
            : [],
      );

      await _firestore.saveUser(newUser);

      // Firebase signs a newly created user in automatically. Registration
      // should finish on the login screen, so clear that temporary session.
      await _auth.signOut();
      _currentUser = null;
      notifyListeners();

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

  Future<String> _uploadImageToStorage(
    String userId,
    Uint8List imageBytes,
    String folder,
  ) async {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child(folder)
        .child('$userId.jpg');
    final uploadTask = storageRef.putData(imageBytes);
    final snapshot = await uploadTask.whenComplete(() => {});
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> updateProfilePicture(Uint8List imageBytes) async {
    if (_currentUser == null) return;
    try {
      final imageUrl = await _uploadImageToStorage(
        _currentUser!.uid,
        imageBytes,
        'profile_pictures',
      );
      await _firestore.updateUserProfile(_currentUser!.uid, {
        'profilePicture': imageUrl,
      });
      // Refresh the local user data
      _currentUser = await _firestore.getUser(_currentUser!.uid);
      notifyListeners();
    } catch (e) {
      print("❌ Upload failed: $e");
      rethrow;
    }
  }

  Future<void> updateActiveCourse({
    required String courseId,
    required String courseName,
  }) async {
    final user = _currentUser;
    if (user == null) return;

    await _firestore.updateActiveModule(
      uid: user.uid,
      moduleId: courseId,
      moduleName: courseName,
      courseId: courseId,
      courseName: courseName,
    );
    _currentUser = await _firestore.getUser(user.uid);
    notifyListeners();
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
