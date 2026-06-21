import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/notification_settings.dart';
import '../repositories/notification_repository.dart';
import '../services/fcm_service.dart';
import '../utils/in_app_notification_helper.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _repository;
  
  NotificationSettingsModel? _settings;
  bool _isLoading = false;
  String? _errorMessage;
  String? _activeUid;
  StreamSubscription<NotificationSettingsModel?>? _settingsSubscription;

  Timer? _checkTimer;
  final Map<int, String> _lastShownReminders = {};

  NotificationProvider({NotificationRepository? repository})
      : _repository = repository ?? NotificationRepository();

  // Getters
  NotificationSettingsModel? get settings => _settings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void initialize(String uid) {
    if (_activeUid == uid) return;
    _activeUid = uid;
    _setLoading(true);

    _settingsSubscription?.cancel();
    _settingsSubscription = _repository.getNotificationSettingsStream(uid).listen((data) async {
      if (data == null) {
        // Create default settings if none exist
        _settings = NotificationSettingsModel.defaultSettings();
        await saveSettings(_settings!);
      } else {
        _settings = data;
        // Sync local scheduled notifications
        await FcmService.instance.updateScheduledNotifications(_settings!);
      }
      _startReminderCheck();
      _setLoading(false);
      notifyListeners();
    }, onError: (err) {
      _errorMessage = err.toString();
      _setLoading(false);
      notifyListeners();
    });
  }

  void clear() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _lastShownReminders.clear();
    _activeUid = null;
    _settings = null;
    _settingsSubscription?.cancel();
    _settingsSubscription = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<bool> saveSettings(NotificationSettingsModel newSettings) async {
    if (_activeUid == null) return false;
    try {
      await _repository.saveNotificationSettings(
        _activeUid!, 
        newSettings.copyWith(updatedAt: DateTime.now()),
      );

      // Sync FCM topic subscriptions to match the new preferences.
      await FcmService.instance.syncTopics(
        dailyReminder: newSettings.dailyReminder,
        medicineReminder: newSettings.medicineReminder,
        glucoseReminder: newSettings.glucoseReminder,
        riskPrediction: newSettings.riskPredictionNotification,
      );

      // Sync local scheduled notifications
      await FcmService.instance.updateScheduledNotifications(newSettings);

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  void _startReminderCheck() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _checkReminders();
    });
  }

  void _checkReminders() {
    final settings = _settings;
    if (settings == null) return;

    final now = DateTime.now();
    final currentTimeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // 1. Daily Reminder
    if (settings.dailyReminder && settings.dailyReminderTime == currentTimeString) {
      _triggerReminder(
        id: 1,
        timeString: currentTimeString,
        title: 'Pengingat Harian DiaCare ☀️',
        body: 'Jangan lupa untuk mencatat aktivitas dan memantau kondisi kesehatan Anda hari ini!',
      );
    }

    // 2. Medicine Reminder
    if (settings.medicineReminder && settings.medicineReminderTime == currentTimeString) {
      _triggerReminder(
        id: 2,
        timeString: currentTimeString,
        title: 'Pengingat Minum Obat 💊',
        body: 'Saatnya meminum obat Anda sesuai jadwal agar kesehatan tetap terjaga.',
      );
    }

    // 3. Glucose Reminder
    if (settings.glucoseReminder && settings.glucoseReminderTime == currentTimeString) {
      _triggerReminder(
        id: 3,
        timeString: currentTimeString,
        title: 'Pengingat Cek Gula Darah 🩸',
        body: 'Sudahkah Anda mengecek gula darah hari ini? Mari pantau kadar glukosa Anda.',
      );
    }
  }

  void _triggerReminder({
    required int id,
    required String timeString,
    required String title,
    required String body,
  }) {
    if (_lastShownReminders[id] == timeString) return;
    _lastShownReminders[id] = timeString;

    debugPrint('NotificationProvider: Triggering reminder ID $id ($title) for time $timeString');

    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState != null) {
      InAppNotificationHelper.show(
        overlayState: overlayState,
        title: title,
        body: body,
        icon: id == 1
            ? Icons.wb_sunny_rounded
            : (id == 2 ? Icons.medication_rounded : Icons.water_drop_rounded),
        iconColor: id == 1
            ? const Color(0xFFF59E0B)
            : (id == 2 ? const Color(0xFF10B981) : const Color(0xFF3B82F6)),
      );
    } else {
      debugPrint('NotificationProvider: overlayState is null, cannot show in-app banner');
    }

    // Trigger system notification
    FcmService.instance.showLocalNotification(
      id: id,
      title: title,
      body: body,
    );
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _settingsSubscription?.cancel();
    super.dispose();
  }
}
