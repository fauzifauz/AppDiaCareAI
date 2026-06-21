import 'package:flutter/material.dart';

class FeatureContribution {
  final String name;
  final String valueText;
  final double contributionPercentage;
  final IconData icon;
  final String description;
  final String impactMessage;

  FeatureContribution({
    required this.name,
    required this.valueText,
    required this.contributionPercentage,
    required this.icon,
    required this.description,
    required this.impactMessage,
  });

  factory FeatureContribution.fromJson(Map<dynamic, dynamic> json) {
    final nameStr = json['name']?.toString() ?? '';
    return FeatureContribution(
      name: nameStr,
      valueText: json['valueText']?.toString() ?? '',
      contributionPercentage: (json['contributionPercentage'] as num?)?.toDouble() ?? 0.0,
      description: json['description']?.toString() ?? '',
      impactMessage: json['impactMessage']?.toString() ?? '',
      icon: _getIconForFeature(nameStr),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'valueText': valueText,
      'contributionPercentage': contributionPercentage,
      'description': description,
      'impactMessage': impactMessage,
    };
  }

  static IconData _getIconForFeature(String name) {
    switch (name) {
      case 'Kadar HbA1c': return Icons.water_drop_rounded;
      case 'Glukosa Darah': return Icons.bloodtype_rounded;
      case 'Indeks Massa Tubuh': return Icons.monitor_weight_rounded;
      case 'Tekanan Darah Tinggi': return Icons.speed_rounded;
      case 'Penyakit Jantung': return Icons.favorite_rounded;
      case 'Faktor Usia': return Icons.calendar_month_rounded;
      case 'Riwayat Merokok': return Icons.smoking_rooms_rounded;
      case 'Jenis Kelamin': return Icons.person_rounded;
      default: return Icons.info_outline_rounded;
    }
  }
}

class RiskPredictionModel {
  final String predictionId;
  final double riskPercentage;
  final double metabolicScore;
  final String riskLevel;
  final String timestamp;
  final double age;
  final double bmi;
  final double hba1c;
  final double glucose;
  final String gender;
  final bool hypertension;
  final bool heartDisease;
  final String smokingHistory;
  final List<String> recommendations;
  final List<FeatureContribution> contributions;
  final String modelTransparency;

  RiskPredictionModel({
    required this.predictionId,
    required this.riskPercentage,
    required this.metabolicScore,
    required this.riskLevel,
    required this.timestamp,
    required this.age,
    required this.bmi,
    required this.hba1c,
    required this.glucose,
    required this.gender,
    required this.hypertension,
    required this.heartDisease,
    required this.smokingHistory,
    required this.recommendations,
    required this.contributions,
    required this.modelTransparency,
  });

  factory RiskPredictionModel.fromJson(Map<dynamic, dynamic> json) {
    return RiskPredictionModel(
      predictionId: json['predictionId']?.toString() ?? '',
      riskPercentage: (json['riskPercentage'] as num?)?.toDouble() ?? 0.0,
      metabolicScore: (json['metabolicScore'] as num?)?.toDouble() ?? 100.0,
      riskLevel: json['riskLevel']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
      age: (json['age'] as num?)?.toDouble() ?? 0.0,
      bmi: (json['bmi'] as num?)?.toDouble() ?? 0.0,
      hba1c: (json['hba1c'] as num?)?.toDouble() ?? 0.0,
      glucose: (json['glucose'] as num?)?.toDouble() ?? 0.0,
      gender: json['gender']?.toString() ?? '',
      hypertension: json['hypertension'] as bool? ?? false,
      heartDisease: json['heartDisease'] as bool? ?? false,
      smokingHistory: json['smokingHistory']?.toString() ?? '',
      recommendations: json['recommendations'] != null
          ? List<String>.from((json['recommendations'] as List).map((item) => item.toString()))
          : [],
      contributions: json['contributions'] != null
          ? List<FeatureContribution>.from((json['contributions'] as List)
              .map((item) => FeatureContribution.fromJson(item as Map)))
          : [],
      modelTransparency: json['modelTransparency']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'predictionId': predictionId,
      'riskPercentage': riskPercentage,
      'metabolicScore': metabolicScore,
      'riskLevel': riskLevel,
      'timestamp': timestamp,
      'age': age,
      'bmi': bmi,
      'hba1c': hba1c,
      'glucose': glucose,
      'gender': gender,
      'hypertension': hypertension,
      'heartDisease': heartDisease,
      'smokingHistory': smokingHistory,
      'recommendations': recommendations,
      'contributions': contributions.map((c) => c.toJson()).toList(),
      'modelTransparency': modelTransparency,
    };
  }
}
