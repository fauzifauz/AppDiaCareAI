import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../models/sensor_data.dart';

class FirebaseSensorService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  // Node path helper inside Firebase Realtime Database
  String _getSensorPath() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return 'sensor_data/anonymous';
    }
    return 'users/$uid/sensor_data';
  }

  /// Stream of [SensorData] changes in real-time.
  /// Listeners will automatically receive new values when database changes.
  Stream<SensorData> getSensorDataStream() {
    return _database.ref(_getSensorPath()).onValue.map((event) {
      final snapshot = event.snapshot;
      if (snapshot.value == null) {
        debugPrint('FirebaseSensorService: Database snapshot is null or empty.');
        return SensorData.initial();
      }

      // Convert data format safely
      try {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        return SensorData.fromJson(data);
      } catch (e) {
        debugPrint('FirebaseSensorService: Error parsing sensor data: $e');
        throw FormatException('Gagal memproses data sensor dari server: $e');
      }
    }).handleError((error) {
      debugPrint('FirebaseSensorService: Database stream error: $error');
      // Propagate error to StreamBuilder
      throw Exception('Gagal menghubungkan ke database: $error');
    });
  }

  /// Writes data directly to Firebase Realtime Database.
  /// This is used to update the sensor values (e.g. from IoT devices or dashboard simulation).
  Future<void> updateSensorData({
    required double temperature,
    required double humidity,
    required double glucose,
  }) async {
    try {
      final Map<String, dynamic> update = {
        'temperature': temperature,
        'humidity': humidity,
        'glucose': glucose,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      await _database.ref(_getSensorPath()).update(update);
      debugPrint('FirebaseSensorService: Sensor data updated successfully: $update');
    } catch (e) {
      debugPrint('FirebaseSensorService: Error writing sensor data: $e');
      throw Exception('Gagal menyimpan data ke Firebase: $e');
    }
  }

  /// Helper tool for local testing and simulation.
  /// Automatically generates periodic changes to Firebase Realtime Database.
  Timer? _simulationTimer;
  
  void startSimulation() {
    _simulationTimer?.cancel();
    
    // Initial update
    updateSensorData(temperature: 36.2, humidity: 45.0, glucose: 95.0);
    
    // Periodically update sensor values every 5 seconds
    _simulationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // Simulate biological and environment jitter
      final double nextTemp = 35.8 + (timer.tick % 5) * 0.2; // fluctuates between 35.8 and 36.8
      final double nextHumid = 40.0 + (timer.tick % 7) * 2.5; // fluctuates between 40.0 and 55.0
      
      // Simulate glucose fluctuations (cycles normal, prediabetes, high)
      double nextGlucose = 90.0 + (timer.tick % 12) * 8.0; 
      if (nextGlucose > 180) {
        nextGlucose = 75.0; // cycle back
      }

      updateSensorData(
        temperature: double.parse(nextTemp.toStringAsFixed(1)),
        humidity: double.parse(nextHumid.toStringAsFixed(1)),
        glucose: double.parse(nextGlucose.toStringAsFixed(1)),
      );
    });
    
    debugPrint('FirebaseSensorService: Sensor simulation started.');
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    debugPrint('FirebaseSensorService: Sensor simulation stopped.');
  }
}
