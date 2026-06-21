import 'package:flutter/foundation.dart';

@immutable
class HealthRecord {
  final String recordId;
  final double glucoseLevel;
  final String bloodPressure;
  final double heartRate;
  final double weight;
  final double bmi;
  final int steps;
  final String notes;
  final String timestamp;

  const HealthRecord({
    required this.recordId,
    required this.glucoseLevel,
    required this.bloodPressure,
    required this.heartRate,
    required this.weight,
    required this.bmi,
    required this.steps,
    required this.notes,
    required this.timestamp,
  });

  /// Factory constructor to parse [HealthRecord] from map data.
  factory HealthRecord.fromJson(Map<dynamic, dynamic> json) {
    return HealthRecord(
      recordId: json['recordId']?.toString() ?? '',
      glucoseLevel: (json['glucoseLevel'] as num?)?.toDouble() ?? 0.0,
      bloodPressure: json['bloodPressure']?.toString() ?? '',
      heartRate: (json['heartRate'] as num?)?.toDouble() ?? 0.0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      bmi: (json['bmi'] as num?)?.toDouble() ?? 0.0,
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      notes: json['notes']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
    );
  }

  /// Convert to JSON map for database operations.
  Map<String, dynamic> toJson() {
    return {
      'recordId': recordId,
      'glucoseLevel': glucoseLevel,
      'bloodPressure': bloodPressure,
      'heartRate': heartRate,
      'weight': weight,
      'bmi': bmi,
      'steps': steps,
      'notes': notes,
      'timestamp': timestamp,
    };
  }

  /// Creates a copy of this [HealthRecord] but with the given fields replaced with the new values.
  HealthRecord copyWith({
    String? recordId,
    double? glucoseLevel,
    String? bloodPressure,
    double? heartRate,
    double? weight,
    double? bmi,
    int? steps,
    String? notes,
    String? timestamp,
  }) {
    return HealthRecord(
      recordId: recordId ?? this.recordId,
      glucoseLevel: glucoseLevel ?? this.glucoseLevel,
      bloodPressure: bloodPressure ?? this.bloodPressure,
      heartRate: heartRate ?? this.heartRate,
      weight: weight ?? this.weight,
      bmi: bmi ?? this.bmi,
      steps: steps ?? this.steps,
      notes: notes ?? this.notes,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Calculates BMI based on weight (kg) and height (cm).
  static double calculateBMI(double weightKg, double heightCm) {
    if (heightCm <= 0) return 0.0;
    final double heightM = heightCm / 100.0;
    return weightKg / (heightM * heightM);
  }

  /// Returns BMI status category label.
  String get bmiStatus {
    if (bmi <= 0) return 'N/A';
    if (bmi < 18.5) return 'Kurus';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Kelebihan Berat';
    return 'Obesitas';
  }

  /// Returns status label for glucose.
  String get glucoseStatus {
    if (glucoseLevel <= 0) return 'N/A';
    if (glucoseLevel < 70) return 'Rendah';
    if (glucoseLevel <= 140) return 'Normal';
    if (glucoseLevel <= 200) return 'Tinggi';
    return 'Sangat Tinggi';
  }
}
