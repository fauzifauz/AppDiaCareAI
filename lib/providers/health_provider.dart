import 'dart:async';
import 'package:flutter/material.dart';
import '../models/health_record.dart';
import '../models/activity_log.dart';
import '../models/risk_prediction.dart';
import '../repositories/database_repository.dart';

class HealthProvider extends ChangeNotifier {
  final DatabaseRepository _dbRepository;

  List<HealthRecord> _records = [];
  List<ActivityLog> _logs = [];
  List<RiskPredictionModel> _predictions = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _activeUid;

  StreamSubscription<List<HealthRecord>>? _historySubscription;
  StreamSubscription<List<ActivityLog>>? _logsSubscription;
  StreamSubscription<List<RiskPredictionModel>>? _predictionsSubscription;


  HealthProvider({DatabaseRepository? dbRepository})
      : _dbRepository = dbRepository ?? DatabaseRepository();

  // Getters
  List<HealthRecord> get records => _records;
  List<ActivityLog> get logs => _logs;
  List<RiskPredictionModel> get predictions => _predictions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;


  /// Starts listening to real-time streams for the authenticated user.
  void initialize(String uid) {
    if (_activeUid == uid) return;
    _activeUid = uid;
    
    _setLoading(true);

    // Subscribe to health records
    _historySubscription?.cancel();
    _historySubscription = _dbRepository.getHealthHistoryStream(uid).listen((data) {
      _records = data;
      _setLoading(false);
      notifyListeners();
    }, onError: (err) {
      _errorMessage = err.toString();
      _setLoading(false);
      notifyListeners();
    });

    // Subscribe to activity logs
    _logsSubscription?.cancel();
    _logsSubscription = _dbRepository.getActivityLogsStream(uid).listen((data) {
      _logs = data;
      notifyListeners();
    });

    // Subscribe to risk predictions
    _predictionsSubscription?.cancel();
    _predictionsSubscription = _dbRepository.getRiskPredictionsStream(uid).listen((data) {
      _predictions = data;
      notifyListeners();
    });
  }


  /// Clears streams when the user logs out.
  void clear() {
    _activeUid = null;
    _records.clear();
    _logs.clear();
    _predictions.clear();
    _historySubscription?.cancel();
    _historySubscription = null;
    _logsSubscription?.cancel();
    _logsSubscription = null;
    _predictionsSubscription?.cancel();
    _predictionsSubscription = null;
    notifyListeners();
  }


  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // ================= CRUD API =================

  /// Adds a health record.
  Future<bool> addHealthRecord(HealthRecord record) async {
    if (_activeUid == null) return false;
    try {
      await _dbRepository.addHealthRecord(_activeUid!, record);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Edits a health record.
  Future<bool> editHealthRecord(HealthRecord record) async {
    if (_activeUid == null) return false;
    try {
      await _dbRepository.editHealthRecord(_activeUid!, record);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Deletes a health record.
  Future<bool> removeHealthRecord(String recordId) async {
    if (_activeUid == null) return false;
    try {
      await _dbRepository.removeHealthRecord(_activeUid!, recordId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Deletes a risk prediction.
  Future<bool> removeRiskPrediction(String predictionId) async {
    if (_activeUid == null) return false;
    try {
      await _dbRepository.deleteRiskPrediction(_activeUid!, predictionId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Log custom activities (e.g. view dashboard, profile, predictions).
  Future<void> logCustomActivity(String action, String description) async {
    if (_activeUid == null) return;
    await _dbRepository.logActivity(
      uid: _activeUid!,
      action: action,
      description: description,
    );
  }

  // ================= COMPUTED STATISTICS GETTERS =================

  /// Latest health record, if any.
  HealthRecord? get latestRecord => _records.isNotEmpty ? _records.first : null;

  /// Total count of saved records.
  int get totalRecordsCount => _records.length;

  /// Average blood glucose level.
  double get averageGlucose {
    if (_records.isEmpty) return 0.0;
    final double sum = _records.map((r) => r.glucoseLevel).reduce((a, b) => a + b);
    return sum / _records.length;
  }

  /// Average daily steps.
  double get averageSteps {
    final validRecords = _records.where((r) => r.steps > 0).toList();
    if (validRecords.isEmpty) return 0.0;
    final double sum = validRecords.map((r) => r.steps.toDouble()).reduce((a, b) => a + b);
    return sum / validRecords.length;
  }

  /// Latest activity log recorded.
  ActivityLog? get latestActivityLog => _logs.isNotEmpty ? _logs.first : null;

  @override
  void dispose() {
    _historySubscription?.cancel();
    _logsSubscription?.cancel();
    super.dispose();
  }
}
