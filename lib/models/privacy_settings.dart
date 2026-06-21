import 'package:cloud_firestore/cloud_firestore.dart';

class PrivacySettingsModel {
  final bool shareAnalytics;
  final bool storeHistory;
  final DateTime updatedAt;

  PrivacySettingsModel({
    required this.shareAnalytics,
    required this.storeHistory,
    required this.updatedAt,
  });

  factory PrivacySettingsModel.fromJson(Map<dynamic, dynamic> json) {
    DateTime parsedDate = DateTime.now();
    final rawUpdatedAt = json['updatedAt'];
    if (rawUpdatedAt != null) {
      if (rawUpdatedAt is String) {
        parsedDate = DateTime.tryParse(rawUpdatedAt) ?? DateTime.now();
      } else if (rawUpdatedAt is Timestamp) {
        parsedDate = rawUpdatedAt.toDate();
      } else if (rawUpdatedAt is int) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(rawUpdatedAt);
      }
    }
    return PrivacySettingsModel(
      shareAnalytics: json['shareAnalytics'] as bool? ?? false,
      storeHistory: json['storeHistory'] as bool? ?? true,
      updatedAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shareAnalytics': shareAnalytics,
      'storeHistory': storeHistory,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory PrivacySettingsModel.defaultSettings() {
    return PrivacySettingsModel(
      shareAnalytics: false,
      storeHistory: true,
      updatedAt: DateTime.now(),
    );
  }

  PrivacySettingsModel copyWith({
    bool? shareAnalytics,
    bool? storeHistory,
    DateTime? updatedAt,
  }) {
    return PrivacySettingsModel(
      shareAnalytics: shareAnalytics ?? this.shareAnalytics,
      storeHistory: storeHistory ?? this.storeHistory,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
