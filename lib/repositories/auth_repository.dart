import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/fcm_service.dart';

class AuthRepository {
  final AuthService _authService;
  final DatabaseService _dbService;

  AuthRepository({
    AuthService? authService,
    DatabaseService? dbService,
  })  : _authService = authService ?? AuthService(),
        _dbService = dbService ?? DatabaseService();

  /// Expose standard auth state changes.
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  /// Expose the current user instance.
  User? get currentUser => _authService.currentUser;

  /// Registers user and writes their initial profile to Database.
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String fullName,
    required String gender,
    required int age,
  }) async {
    final creds = await _authService.signUp(email, password);
    final uid = creds.user?.uid;

    if (uid != null) {
      final now = DateTime.now().toIso8601String();
      final userProfile = UserModel(
        uid: uid,
        fullName: fullName,
        email: email,
        gender: gender,
        age: age,
        createdAt: now,
        lastLogin: now,
      );
      
      // Save profile to database
      await _dbService.createUserProfile(uid, userProfile);
    }

    return creds;
  }

  /// Signs in the user and updates their last login timestamp and FCM token.
  Future<UserCredential> signIn(String email, String password) async {
    final creds = await _authService.signIn(email, password);
    final uid = creds.user?.uid;

    if (uid != null) {
      final now = DateTime.now().toIso8601String();
      await _dbService.updateUserProfile(uid, {'lastLogin': now});

      // Save current device FCM token
      final token = await FcmService.instance.getToken();
      if (token != null) {
        await _dbService.saveFcmToken(uid, token);
      }
    }

    return creds;
  }

  /// Signs in a user using Google Sign-In.
  /// If the user is new, creates a default user profile in the database.
  /// If the user is existing, updates their last login timestamp and FCM token.
  Future<UserCredential> signInWithGoogle() async {
    final creds = await _authService.signInWithGoogle();
    final uid = creds.user?.uid;

    if (uid != null) {
      final existingProfile = await _dbService.getUserProfile(uid);
      final now = DateTime.now().toIso8601String();

      if (existingProfile == null) {
        // Create default profile for new Google user
        final defaultProfile = UserModel(
          uid: uid,
          fullName: creds.user?.displayName ?? 'Pengguna Google',
          email: creds.user?.email ?? '',
          gender: 'Laki-laki',
          age: 0,
          createdAt: now,
          lastLogin: now,
          photoUrl: creds.user?.photoURL ?? '',
        );
        await _dbService.createUserProfile(uid, defaultProfile);
      } else {
        // Update last login for existing Google user
        await _dbService.updateUserProfile(uid, {'lastLogin': now});
      }

      // Save current device FCM token
      final token = await FcmService.instance.getToken();
      if (token != null) {
        await _dbService.saveFcmToken(uid, token);
      }
    }

    return creds;
  }

  /// Signs out.
  Future<void> signOut() async {
    await _authService.signOut();
  }

  /// Resets password.
  Future<void> resetPassword(String email) async {
    await _authService.sendPasswordResetEmail(email);
  }

  /// Sends account verification email.
  Future<void> sendEmailVerification() async {
    await _authService.sendEmailVerification();
  }

  /// Reloads current user state from Firebase.
  Future<void> reloadUser() async {
    await _authService.reloadUser();
  }

  /// Updates user email address.
  Future<void> updateEmail(String newEmail) async {
    await _authService.updateEmail(newEmail);
  }

  /// Fetches enrolled MFA factors.
  Future<List<MultiFactorInfo>> getEnrolledMfaFactors() async {
    return await _authService.getEnrolledMfaFactors();
  }

  /// Starts SMS phone MFA enrollment.
  Future<void> startPhoneMfaEnrollment({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(Exception error) onError,
  }) async {
    await _authService.startPhoneMfaEnrollment(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onError: onError,
    );
  }

  /// Finalizes phone MFA enrollment.
  Future<void> finalizePhoneMfaEnrollment({
    required String verificationId,
    required String smsCode,
    required String displayName,
  }) async {
    await _authService.finalizePhoneMfaEnrollment(
      verificationId: verificationId,
      smsCode: smsCode,
      displayName: displayName,
    );
  }

  /// Unenrolls a specific MFA factor.
  Future<void> unenrollMfa(String factorId) async {
    await _authService.unenrollMfa(factorId);
  }
}
