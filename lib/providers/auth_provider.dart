import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/database_repository.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  final DatabaseRepository _dbRepository;
  final StorageService _storageService;

  User? _firebaseUser;
  UserModel? _userProfile;
  List<MultiFactorInfo> _enrolledMfaFactors = [];
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  String? _errorMessage;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserModel?>? _profileSubscription;

  AuthProvider({
    AuthRepository? authRepository,
    DatabaseRepository? dbRepository,
    StorageService? storageService,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _dbRepository = dbRepository ?? DatabaseRepository(),
        _storageService = storageService ?? StorageService() {
    _init();
  }

  // Getters
  User? get firebaseUser => _firebaseUser;
  UserModel? get userProfile => _userProfile;
  List<MultiFactorInfo> get enrolledMfaFactors => _enrolledMfaFactors;
  bool get isAuthenticated => _firebaseUser != null;
  bool get isLoading => _isLoading;
  bool get isUploadingPhoto => _isUploadingPhoto;
  String? get errorMessage => _errorMessage;

  void _init() {
    _authSubscription = _authRepository.authStateChanges.listen((User? user) {
      _firebaseUser = user;
      
      // If user logs out, clear profile subscriptions
      if (user == null) {
        _userProfile = null;
        _enrolledMfaFactors = [];
        _profileSubscription?.cancel();
        _profileSubscription = null;
        notifyListeners();
      } else {
        // If user logs in, subscribe to user profile in database
        _subscribeToUserProfile(user.uid);
        fetchMfaFactors();
      }
    });
  }

  void _subscribeToUserProfile(String uid) {
    _profileSubscription?.cancel();
    _profileSubscription = _dbRepository.getUserProfileStream(uid).listen((profile) {
      _userProfile = profile;
      notifyListeners();
    });
  }

  Future<void> fetchMfaFactors() async {
    try {
      _enrolledMfaFactors = await _authRepository.getEnrolledMfaFactors();
      notifyListeners();
    } catch (e) {
      debugPrint('AuthProvider: fetchMfaFactors error: $e');
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  /// Logs in a user using email and password.
  Future<bool> signIn(String email, String password) async {
    _clearError();
    _setLoading(true);
    try {
      await _authRepository.signIn(email, password);
      
      // Audit log (after profile is fetched/synced)
      final uid = _authRepository.currentUser?.uid;
      if (uid != null) {
        await _dbRepository.logActivity(
          uid: uid,
          action: 'Login',
          description: 'Pengguna berhasil login menggunakan email.',
        );
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Registers a new user and automatically sends a verification email.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String gender,
    required int age,
  }) async {
    _clearError();
    _setLoading(true);
    try {
      final creds = await _authRepository.signUp(
        email: email,
        password: password,
        fullName: fullName,
        gender: gender,
        age: age,
      );
      
      final uid = creds.user?.uid;
      if (uid != null) {
        await _dbRepository.logActivity(
          uid: uid,
          action: 'Registrasi Akun',
          description: 'Pengguna berhasil mendaftarkan akun baru: $fullName ($email).',
        );

        // Send email verification automatically on register
        try {
          await _authRepository.sendEmailVerification();
          await _dbRepository.logActivity(
            uid: uid,
            action: 'Kirim Email Verifikasi',
            description: 'Email verifikasi dikirimkan ke $email secara otomatis.',
          );
        } catch (verifErr) {
          debugPrint('AuthProvider: Gagal mengirim verifikasi otomatis: $verifErr');
        }
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Logs in a user using Google Sign-In.
  Future<bool> signInWithGoogle() async {
    _clearError();
    _setLoading(true);
    try {
      await _authRepository.signInWithGoogle();
      
      final uid = _authRepository.currentUser?.uid;
      if (uid != null) {
        final displayName = _authRepository.currentUser?.displayName ?? 'Pengguna';
        await _dbRepository.logActivity(
          uid: uid,
          action: 'Login Google',
          description: 'Pengguna $displayName berhasil masuk menggunakan Google.',
        );
      }
      
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Manually triggers sending account verification email.
  Future<bool> sendEmailVerification() async {
    _clearError();
    _setLoading(true);
    try {
      await _authRepository.sendEmailVerification();
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Reloads current user credentials to fetch updated states like emailVerified.
  Future<void> reloadUser() async {
    try {
      await _authRepository.reloadUser();
      _firebaseUser = _authRepository.currentUser;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  /// Triggers a reset password verification email.
  Future<bool> resetPassword(String email) async {
    _clearError();
    _setLoading(true);
    try {
      await _authRepository.resetPassword(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Updates user profile details in the database.
  Future<bool> updateProfile({
    required String fullName,
    required int age,
    required String gender,
  }) async {
    final uid = _firebaseUser?.uid;
    if (uid == null) return false;
    try {
      await _dbRepository.updateUserProfile(uid, {
        'fullName': fullName,
        'age': age,
        'gender': gender,
      });
      
      await _dbRepository.logActivity(
        uid: uid,
        action: 'Ubah Profil',
        description: 'Pengguna memperbarui informasi profil mereka.',
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Uploads a new profile photo to Firebase Storage and saves the URL to RTDB.
  ///
  /// Returns the download URL on success, or null on failure.
  Future<String?> uploadAndSavePhoto(
    XFile imageFile, {
    void Function(double)? onProgress,
  }) async {
    final uid = _firebaseUser?.uid;
    if (uid == null) return null;

    _isUploadingPhoto = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final photoUrl = await _storageService.uploadProfilePhoto(
        uid: uid,
        imageFile: imageFile,
        onProgress: onProgress,
      );

      // Persist URL to RTDB
      await _dbRepository.updatePhotoUrl(uid, photoUrl);

      // Log the action
      await _dbRepository.logActivity(
        uid: uid,
        action: 'Ubah Foto Profil',
        description: 'Pengguna mengunggah foto profil baru.',
      );

      _isUploadingPhoto = false;
      notifyListeners();
      return photoUrl;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isUploadingPhoto = false;
      notifyListeners();
      return null;
    }
  }

  /// Signs out.
  Future<void> signOut() async {
    final uid = _firebaseUser?.uid;
    if (uid != null) {
      // Log sign out before clearing authentication status
      await _dbRepository.logActivity(
        uid: uid,
        action: 'Logout',
        description: 'Pengguna keluar dari aplikasi.',
      );
    }
    await _authRepository.signOut();
  }

  /// Updates the user email address.
  /// Sends a verification email to the new address and registers log activity.
  Future<bool> updateEmail(String newEmail) async {
    _clearError();
    _setLoading(true);
    final uid = _firebaseUser?.uid;
    if (uid == null) {
      _errorMessage = 'Pengguna tidak ditemukan.';
      _setLoading(false);
      return false;
    }
    final oldEmail = _firebaseUser?.email;
    try {
      debugPrint('AuthProvider: Memulai alur pembaruan email untuk UID $uid (dari $oldEmail ke $newEmail)');
      
      // Update email on Firebase Auth (sends verification email to newEmail)
      await _authRepository.updateEmail(newEmail);
      
      // Update email on Realtime Database profile node
      await _dbRepository.updateUserProfile(uid, {'email': newEmail});
      
      // Log activity
      await _dbRepository.logActivity(
        uid: uid,
        action: 'Ubah Alamat Email',
        description: 'Pengguna meminta pembaruan email dari $oldEmail ke $newEmail. Email verifikasi dikirim.',
      );

      debugPrint('AuthProvider: Pembaruan email berhasil diajukan dan dikirim ke $newEmail');
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('AuthProvider: Gagal memperbarui email untuk UID $uid. Error: $e');
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Request phone verification SMS for MFA.
  Future<void> startPhoneMfa({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
  }) async {
    _clearError();
    try {
      await _authRepository.startPhoneMfaEnrollment(
        phoneNumber: phoneNumber,
        onCodeSent: onCodeSent,
        onError: (err) {
          _errorMessage = err.toString().replaceAll('Exception: ', '');
          notifyListeners();
          onError(_errorMessage!);
        },
      );
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      onError(_errorMessage!);
    }
  }

  /// Confirms the phone verification code and enrolls the user.
  Future<bool> finalizePhoneMfa({
    required String verificationId,
    required String smsCode,
    required String displayName,
  }) async {
    _clearError();
    _setLoading(true);
    final uid = _firebaseUser?.uid;
    if (uid == null) {
      _errorMessage = 'Pengguna tidak ditemukan.';
      _setLoading(false);
      return false;
    }
    try {
      await _authRepository.finalizePhoneMfaEnrollment(
        verificationId: verificationId,
        smsCode: smsCode,
        displayName: displayName,
      );

      // Log the activity
      await _dbRepository.logActivity(
        uid: uid,
        action: 'Aktivasi MFA',
        description: 'Pengguna mengaktifkan Otentikasi Dua Faktor (MFA) menggunakan nomor $displayName.',
      );

      // Fetch updated MFA factors list
      await fetchMfaFactors();
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Disables Multi-Factor Authentication (MFA).
  Future<bool> disableMfa(String factorId) async {
    _clearError();
    _setLoading(true);
    final uid = _firebaseUser?.uid;
    if (uid == null) {
      _errorMessage = 'Pengguna tidak ditemukan.';
      _setLoading(false);
      return false;
    }
    try {
      await _authRepository.unenrollMfa(factorId);

      // Log the activity
      await _dbRepository.logActivity(
        uid: uid,
        action: 'Deaktivasi MFA',
        description: 'Pengguna menonaktifkan Otentikasi Dua Faktor (MFA).',
      );

      // Fetch updated list of MFA factors
      await fetchMfaFactors();
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  /// Syncs the local profile email with the actual email from Firebase Auth servers.
  /// Handles cases where user verifies a new email or clicks a revocation link.
  Future<void> syncEmailWithFirebase() async {
    final user = _authRepository.currentUser;
    if (user == null) return;
    try {
      await user.reload();
      final freshUser = _authRepository.currentUser;
      final freshEmail = freshUser?.email;
      if (freshEmail != null && _userProfile != null && _userProfile!.email != freshEmail) {
        final uid = user.uid;
        await _dbRepository.updateUserProfile(uid, {'email': freshEmail});
        await _dbRepository.logActivity(
          uid: uid,
          action: 'Sinkronisasi Email',
          description: 'Sinkronisasi email database dengan Firebase Auth: $freshEmail',
        );
      }
    } catch (e) {
      debugPrint('AuthProvider: syncEmailWithFirebase error: $e');
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }
}
