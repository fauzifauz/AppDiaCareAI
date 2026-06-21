import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/notification_settings.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch notification settings.
  Future<NotificationSettingsModel?> getNotificationSettings(String uid) async {
    try {
      // 1. Try to read from Firebase Realtime Database first
      final snapshot = await FirebaseDatabase.instance
          .ref('users/$uid/notification_settings')
          .get();
      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        return NotificationSettingsModel.fromJson(data);
      }

      // 2. Fallback to Cloud Firestore if RTDB doesn't have it yet
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notification_settings')
          .doc('settings')
          .get();
      if (doc.exists && doc.data() != null) {
        final settings = NotificationSettingsModel.fromJson(doc.data()!);
        
        // Migrate/save to Realtime Database to keep it synced
        final Map<String, dynamic> rtdbMap = settings.toJson();
        rtdbMap['updatedAt'] = settings.updatedAt.toIso8601String();
        await FirebaseDatabase.instance
            .ref('users/$uid/notification_settings')
            .set(rtdbMap);
            
        return settings;
      }
      return null;
    } catch (e) {
      throw Exception('Gagal memuat pengaturan notifikasi: $e');
    }
  }

  /// Listen to real-time notification settings.
  Stream<NotificationSettingsModel?> getNotificationSettingsStream(String uid) {
    return FirebaseDatabase.instance
        .ref('users/$uid/notification_settings')
        .onValue
        .map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) return null;
      final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
      return NotificationSettingsModel.fromJson(data);
    });
  }

  /// Save notification settings.
  Future<void> saveNotificationSettings(String uid, NotificationSettingsModel settings) async {
    try {
      // 1. Save to Cloud Firestore
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notification_settings')
          .doc('settings')
          .set(settings.toJson(), SetOptions(merge: true));

      // 2. Save to Firebase Realtime Database
      final Map<String, dynamic> rtdbMap = settings.toJson();
      rtdbMap['updatedAt'] = settings.updatedAt.toIso8601String();
      await FirebaseDatabase.instance
          .ref('users/$uid/notification_settings')
          .set(rtdbMap);
    } catch (e) {
      throw Exception('Gagal menyimpan pengaturan notifikasi: $e');
    }
  }
}
