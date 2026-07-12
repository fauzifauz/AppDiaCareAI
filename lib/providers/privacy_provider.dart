import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/privacy_settings.dart';
import '../repositories/privacy_repository.dart';
import '../repositories/database_repository.dart';
import '../utils/file_saver.dart';

class PrivacyProvider extends ChangeNotifier {
  final PrivacyRepository _privacyRepository;
  final DatabaseRepository _dbRepository;

  PrivacySettingsModel? _settings;
  bool _isLoading = false;
  bool _isSavingData = false;
  String? _errorMessage;
  String? _successMessage;
  String? _activeUid;
  int _riskPredictionsCount = 0;
  int _sensorDataCount = 0;
  StreamSubscription<PrivacySettingsModel?>? _settingsSubscription;
  StreamSubscription<int>? _predictionsCountSubscription;
  StreamSubscription<int>? _sensorCountSubscription;

  PrivacyProvider({
    PrivacyRepository? privacyRepository,
    DatabaseRepository? dbRepository,
  })  : _privacyRepository = privacyRepository ?? PrivacyRepository(),
        _dbRepository = dbRepository ?? DatabaseRepository();

  // ─── Getters ───────────────────────────────────────────────────────────────
  PrivacySettingsModel? get settings => _settings;
  bool get isLoading => _isLoading;
  bool get isSavingData => _isSavingData;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  int get riskPredictionsCount => _riskPredictionsCount;
  int get sensorDataCount => _sensorDataCount;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────
  void initialize(String uid) {
    if (_activeUid == uid) return;
    _activeUid = uid;
    _setLoading(true);

    _settingsSubscription?.cancel();
    _settingsSubscription =
        _privacyRepository.getPrivacySettingsStream(uid).listen((data) {
      if (data == null) {
        _settings = PrivacySettingsModel.defaultSettings();
        saveSettings(_settings!);
      } else {
        _settings = data;
      }
      _setLoading(false);
      notifyListeners();
    }, onError: (err) {
      _errorMessage = err.toString();
      _setLoading(false);
      notifyListeners();
    });

    _predictionsCountSubscription?.cancel();
    _predictionsCountSubscription =
        _dbRepository.getRiskPredictionsCountStream(uid).listen((count) {
      _riskPredictionsCount = count;
      notifyListeners();
    });

    _sensorCountSubscription?.cancel();
    _sensorCountSubscription =
        _dbRepository.getSensorDataCountStream(uid).listen((count) {
      _sensorDataCount = count;
      notifyListeners();
    });
  }

  void clear() {
    _activeUid = null;
    _settings = null;
    _riskPredictionsCount = 0;
    _sensorDataCount = 0;
    _settingsSubscription?.cancel();
    _predictionsCountSubscription?.cancel();
    _sensorCountSubscription?.cancel();
    _settingsSubscription = null;
    _predictionsCountSubscription = null;
    _sensorCountSubscription = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  // ─── Save settings ─────────────────────────────────────────────────────────
  Future<bool> saveSettings(PrivacySettingsModel newSettings) async {
    if (_activeUid == null) return false;
    try {
      await _privacyRepository.savePrivacySettings(
        _activeUid!,
        newSettings.copyWith(updatedAt: DateTime.now()),
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Download data ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> prepareUserDataExport() async {
    if (_activeUid == null) return null;
    _isSavingData = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      final data = await _dbRepository.exportUserData(_activeUid!);
      _isSavingData = false;
      notifyListeners();
      return data;
    } catch (e) {
      _errorMessage = e.toString();
      _isSavingData = false;
      notifyListeners();
      return null;
    }
  }

  // ─── Clear history ──────────────────────────────────────────────────────────
  Future<bool> clearAllHistory() async {
    if (_activeUid == null) return false;
    _isSavingData = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _dbRepository.clearUserHistory(_activeUid!);
      _successMessage = 'Semua riwayat berhasil dihapus.';
      _riskPredictionsCount = 0;
      _sensorDataCount = 0;
      _isSavingData = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal menghapus riwayat: $e';
      _isSavingData = false;
      notifyListeners();
      return false;
    }
  }
}
