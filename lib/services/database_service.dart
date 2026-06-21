import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/health_record.dart';
import '../models/activity_log.dart';
import '../models/risk_prediction.dart';


class DatabaseService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // Path constants
  static const String _usersNode = 'users';
  static const String _historyNode = 'health_history';
  static const String _logsNode = 'activity_logs';

  /// Save/create user profile node in RTDB.
  Future<void> createUserProfile(String uid, UserModel user) async {
    try {
      await _db.ref('$_usersNode/$uid').set(user.toJson());
      debugPrint('DatabaseService: User profile created for UID: $uid');
    } catch (e) {
      debugPrint('DatabaseService: createUserProfile error: $e');
      throw Exception('Gagal menyimpan profil pengguna.');
    }
  }

  /// Saves the FCM registration token for the given user.
  Future<void> saveFcmToken(String uid, String token) async {
    try {
      await _db.ref('$_usersNode/$uid').update({'fcmToken': token});
      debugPrint('DatabaseService: FCM token saved for UID: $uid');
    } catch (e) {
      debugPrint('DatabaseService: saveFcmToken error: $e');
      // Non-fatal — do not block app flow if token save fails.
    }
  }

  /// Updates the profile photo URL for the given user.
  Future<void> updatePhotoUrl(String uid, String photoUrl) async {
    try {
      await _db.ref('$_usersNode/$uid').update({'photoUrl': photoUrl});
      debugPrint('DatabaseService: photoUrl updated for UID: $uid');
    } catch (e) {
      debugPrint('DatabaseService: updatePhotoUrl error: $e');
      throw Exception('Gagal menyimpan URL foto profil.');
    }
  }

  /// Update individual fields in user profile.
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _db.ref('$_usersNode/$uid').update(data);
      debugPrint('DatabaseService: User profile updated for UID: $uid');
    } catch (e) {
      debugPrint('DatabaseService: updateUserProfile error: $e');
      throw Exception('Gagal memperbarui profil pengguna.');
    }
  }

  /// Fetch user profile once.
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      final snapshot = await _db.ref('$_usersNode/$uid').get();
      if (!snapshot.exists || snapshot.value == null) return null;
      
      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      return UserModel.fromJson(data);
    } catch (e) {
      debugPrint('DatabaseService: getUserProfile error: $e');
      throw Exception('Gagal mengambil data profil.');
    }
  }

  /// Listen to user profile changes in real-time.
  Stream<UserModel?> getUserProfileStream(String uid) {
    return _db.ref('$_usersNode/$uid').onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) return null;
      
      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      return UserModel.fromJson(data);
    });
  }

  // ================= HEALTH RECORDS CRUD =================

  /// Add a new health record under users/$uid/health_history.
  Future<void> createHealthRecord(String uid, HealthRecord record) async {
    try {
      final ref = _db.ref('$_usersNode/$uid/$_historyNode').push();
      final recordWithId = record.copyWith(recordId: ref.key);
      await ref.set(recordWithId.toJson());
      debugPrint('DatabaseService: Health record added with ID: ${ref.key}');
    } catch (e) {
      debugPrint('DatabaseService: createHealthRecord error: $e');
      throw Exception('Gagal menambahkan catatan kesehatan.');
    }
  }

  /// Update an existing health record.
  Future<void> updateHealthRecord(String uid, HealthRecord record) async {
    try {
      await _db
          .ref('$_usersNode/$uid/$_historyNode/${record.recordId}')
          .update(record.toJson());
      debugPrint('DatabaseService: Health record updated: ${record.recordId}');
    } catch (e) {
      debugPrint('DatabaseService: updateHealthRecord error: $e');
      throw Exception('Gagal memperbarui catatan kesehatan.');
    }
  }

  /// Delete a health record.
  Future<void> deleteHealthRecord(String uid, String recordId) async {
    try {
      await _db.ref('$_usersNode/$uid/$_historyNode/$recordId').remove();
      debugPrint('DatabaseService: Health record deleted: $recordId');
    } catch (e) {
      debugPrint('DatabaseService: deleteHealthRecord error: $e');
      throw Exception('Gagal menghapus catatan kesehatan.');
    }
  }

  /// Real-time stream of health records sorted by timestamp descending.
  Stream<List<HealthRecord>> getHealthRecordsStream(String uid) {
    return _db.ref('$_usersNode/$uid/$_historyNode').onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) return [];

      final Map<dynamic, dynamic> recordsMap = snapshot.value as Map<dynamic, dynamic>;
      final List<HealthRecord> list = [];
      
      recordsMap.forEach((key, value) {
        if (value is Map) {
          list.add(HealthRecord.fromJson(value));
        }
      });

      // Sort by timestamp descending (newest first)
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  // ================= ACTIVITY LOGGING =================

  /// Log a user activity under users/$uid/activity_logs.
  Future<void> logActivity(String uid, ActivityLog log) async {
    try {
      final ref = _db.ref('$_usersNode/$uid/$_logsNode').push();
      final logWithId = ActivityLog(
        logId: ref.key ?? '',
        action: log.action,
        description: log.description,
        device: log.device,
        platform: log.platform,
        timestamp: DateTime.now().toIso8601String(),
      );
      await ref.set(logWithId.toJson());
    } catch (e) {
      debugPrint('DatabaseService: logActivity error: $e');
      // Non-fatal error, do not block main workflow if logging fails
    }
  }

  /// Stream of recent activity logs (limited to last 20 entries).
  Stream<List<ActivityLog>> getActivityLogsStream(String uid) {
    return _db
        .ref('$_usersNode/$uid/$_logsNode')
        .limitToLast(20)
        .onValue
        .map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) return [];

      final Map<dynamic, dynamic> logsMap = snapshot.value as Map<dynamic, dynamic>;
      final List<ActivityLog> list = [];

      logsMap.forEach((key, value) {
        if (value is Map) {
          list.add(ActivityLog.fromJson(value));
        }
      });

      // Sort newest first
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  // ================= SENSOR DATA & RISK PREDICTION HISTORY =================

  /// Save a risk prediction to users/$uid/risk_predictions.
  Future<void> saveRiskPrediction(String uid, Map<String, dynamic> data) async {
    try {
      final ref = _db.ref('$_usersNode/$uid/risk_predictions').push();
      final dataWithId = Map<String, dynamic>.from(data)..['predictionId'] = ref.key;
      await ref.set(dataWithId);
      debugPrint('DatabaseService: Risk prediction saved for UID: $uid');
    } catch (e) {
      debugPrint('DatabaseService: saveRiskPrediction error: $e');
      throw Exception('Gagal menyimpan hasil prediksi risiko.');
    }
  }

  /// Delete a risk prediction from users/$uid/risk_predictions.
  Future<void> deleteRiskPrediction(String uid, String predictionId) async {
    try {
      await _db.ref('$_usersNode/$uid/risk_predictions/$predictionId').remove();
      debugPrint('DatabaseService: Risk prediction deleted: $predictionId');
    } catch (e) {
      debugPrint('DatabaseService: deleteRiskPrediction error: $e');
      throw Exception('Gagal menghapus hasil prediksi risiko.');
    }
  }

  /// Get a stream of risk predictions count for UID.
  Stream<int> getRiskPredictionsCountStream(String uid) {
    return _db.ref('$_usersNode/$uid/risk_predictions').onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) return 0;
      final Map<dynamic, dynamic> dataMap = snapshot.value as Map<dynamic, dynamic>;
      return dataMap.length;
    });
  }

  /// Real-time stream of risk predictions sorted by timestamp descending.
  Stream<List<RiskPredictionModel>> getRiskPredictionsStream(String uid) {
    return _db.ref('$_usersNode/$uid/risk_predictions').onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) return [];

      final Map<dynamic, dynamic> dataMap = snapshot.value as Map<dynamic, dynamic>;
      final List<RiskPredictionModel> list = [];

      dataMap.forEach((key, value) {
        if (value is Map) {
          list.add(RiskPredictionModel.fromJson(value));
        }
      });

      // Sort by timestamp descending (newest first)
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }


  /// Save sensor data history to users/$uid/sensor_data.
  Future<void> saveSensorDataHistory(String uid, Map<String, dynamic> data) async {
    try {
      final ref = _db.ref('$_usersNode/$uid/sensor_data').push();
      await ref.set(data);
      debugPrint('DatabaseService: Sensor data history saved for UID: $uid');
    } catch (e) {
      debugPrint('DatabaseService: saveSensorDataHistory error: $e');
      // Non-fatal, do not block app execution
    }
  }

  /// Get a stream of sensor data history count for UID.
  Stream<int> getSensorDataCountStream(String uid) {
    return _db.ref('$_usersNode/$uid/sensor_data').onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) return 0;
      final Map<dynamic, dynamic> dataMap = snapshot.value as Map<dynamic, dynamic>;
      return dataMap.length;
    });
  }

  /// Clear user's history nodes (sensor_data, risk_predictions, activity_logs, health_history).
  Future<void> clearUserHistory(String uid) async {
    try {
      await _db.ref('$_usersNode/$uid/sensor_data').remove();
      await _db.ref('$_usersNode/$uid/risk_predictions').remove();
      await _db.ref('$_usersNode/$uid/$_logsNode').remove();
      await _db.ref('$_usersNode/$uid/$_historyNode').remove();
      debugPrint('DatabaseService: Cleared history nodes for UID: $uid');
    } catch (e) {
      debugPrint('DatabaseService: clearUserHistory error: $e');
      throw Exception('Gagal menghapus riwayat.');
    }
  }

  /// Export user profile and history nodes.
  Future<Map<String, dynamic>> exportUserData(String uid) async {
    try {
      final profileSnap = await _db.ref('$_usersNode/$uid').get();
      final Map<dynamic, dynamic>? profileVal = profileSnap.value as Map<dynamic, dynamic>?;
      final Map<String, dynamic> profile = profileVal != null 
          ? profileVal.map((key, val) => MapEntry(key.toString(), val))
          : {};
          
      // Exclude sub-collections from profile map to prevent duplicates
      profile.remove('health_history');
      profile.remove('activity_logs');
      profile.remove('sensor_data');
      profile.remove('risk_predictions');

      final sensorSnap = await _db.ref('$_usersNode/$uid/sensor_data').get();
      final Map<dynamic, dynamic>? sensorVal = sensorSnap.value as Map<dynamic, dynamic>?;
      final List<Map<String, dynamic>> sensorDataList = [];
      if (sensorVal != null) {
        sensorVal.forEach((key, val) {
          if (val is Map) {
            sensorDataList.add(val.map((k, v) => MapEntry(k.toString(), v)));
          }
        });
      }

      final predictionSnap = await _db.ref('$_usersNode/$uid/risk_predictions').get();
      final Map<dynamic, dynamic>? predictionVal = predictionSnap.value as Map<dynamic, dynamic>?;
      final List<Map<String, dynamic>> riskPredictionsList = [];
      if (predictionVal != null) {
        predictionVal.forEach((key, val) {
          if (val is Map) {
            riskPredictionsList.add(val.map((k, v) => MapEntry(k.toString(), v)));
          }
        });
      }

      final logsSnap = await _db.ref('$_usersNode/$uid/$_logsNode').get();
      final Map<dynamic, dynamic>? logsVal = logsSnap.value as Map<dynamic, dynamic>?;
      final List<Map<String, dynamic>> activityLogsList = [];
      if (logsVal != null) {
        logsVal.forEach((key, val) {
          if (val is Map) {
            activityLogsList.add(val.map((k, v) => MapEntry(k.toString(), v)));
          }
        });
      }

      return {
        'profile': profile,
        'sensor_data': sensorDataList,
        'risk_predictions': riskPredictionsList,
        'activity_logs': activityLogsList,
      };
    } catch (e) {
      debugPrint('DatabaseService: exportUserData error: $e');
      throw Exception('Gagal mengunduh data pengguna.');
    }
  }
}
