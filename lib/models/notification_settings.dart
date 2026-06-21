import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationSettingsModel {
  final bool dailyReminder;
  final bool medicineReminder;
  final bool glucoseReminder;
  final bool riskPredictionNotification;
  final String dailyReminderTime;
  final String medicineReminderTime;
  final String glucoseReminderTime;
  final DateTime updatedAt;

  NotificationSettingsModel({
    required this.dailyReminder,
    required this.medicineReminder,
    required this.glucoseReminder,
    required this.riskPredictionNotification,
    required this.dailyReminderTime,
    required this.medicineReminderTime,
    required this.glucoseReminderTime,
    required this.updatedAt,
  });

  factory NotificationSettingsModel.fromJson(Map<dynamic, dynamic> json) {
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
    return NotificationSettingsModel(
      dailyReminder: json['dailyReminder'] as bool? ?? false,
      medicineReminder: json['medicineReminder'] as bool? ?? false,
      glucoseReminder: json['glucoseReminder'] as bool? ?? false,
      riskPredictionNotification: json['riskPredictionNotification'] as bool? ?? false,
      dailyReminderTime: json['dailyReminderTime'] as String? ?? json['reminderTime'] as String? ?? '08:00',
      medicineReminderTime: json['medicineReminderTime'] as String? ?? '12:00',
      glucoseReminderTime: json['glucoseReminderTime'] as String? ?? '18:00',
      updatedAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dailyReminder': dailyReminder,
      'medicineReminder': medicineReminder,
      'glucoseReminder': glucoseReminder,
      'riskPredictionNotification': riskPredictionNotification,
      'dailyReminderTime': dailyReminderTime,
      'medicineReminderTime': medicineReminderTime,
      'glucoseReminderTime': glucoseReminderTime,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory NotificationSettingsModel.defaultSettings() {
    return NotificationSettingsModel(
      dailyReminder: true,
      medicineReminder: false,
      glucoseReminder: false,
      riskPredictionNotification: true,
      dailyReminderTime: '08:00',
      medicineReminderTime: '12:00',
      glucoseReminderTime: '18:00',
      updatedAt: DateTime.now(),
    );
  }

  NotificationSettingsModel copyWith({
    bool? dailyReminder,
    bool? medicineReminder,
    bool? glucoseReminder,
    bool? riskPredictionNotification,
    String? dailyReminderTime,
    String? medicineReminderTime,
    String? glucoseReminderTime,
    DateTime? updatedAt,
  }) {
    return NotificationSettingsModel(
      dailyReminder: dailyReminder ?? this.dailyReminder,
      medicineReminder: medicineReminder ?? this.medicineReminder,
      glucoseReminder: glucoseReminder ?? this.glucoseReminder,
      riskPredictionNotification: riskPredictionNotification ?? this.riskPredictionNotification,
      dailyReminderTime: dailyReminderTime ?? this.dailyReminderTime,
      medicineReminderTime: medicineReminderTime ?? this.medicineReminderTime,
      glucoseReminderTime: glucoseReminderTime ?? this.glucoseReminderTime,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

