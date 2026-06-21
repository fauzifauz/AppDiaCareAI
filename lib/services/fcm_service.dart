import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/notification_settings.dart';

// ── Top-level handler for background/terminated FCM messages ────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FcmService [BG]: Message received — ${message.messageId}');
  // No Firebase.initializeApp needed here if it was already initialized.
}

/// Service that wraps all Firebase Cloud Messaging interactions.
///
/// Responsibilities:
///  - Request OS notification permission.
///  - Retrieve & refresh FCM device token.
///  - Subscribe / unsubscribe to named topics.
///  - Show local notifications when the app is in foreground.
///  - Route tapped notification payloads.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static const String _channelId = 'diacare_health_channel';
  static const String _channelName = 'DiaCare Health Alerts';
  static const String _channelDesc = 'Notifikasi kesehatan dan reminder dari DiaCareAI';

  // Topic name constants — used for subscribe / unsubscribe
  static const String topicDailyReminder = 'daily_reminder';
  static const String topicMedicineReminder = 'medicine_reminder';
  static const String topicGlucoseReminder = 'glucose_reminder';
  static const String topicRiskPrediction = 'risk_prediction';

  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Initialization ────────────────────────────────────────────────────────

  /// Call once at app startup (after Firebase.initializeApp).
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Initialize timezone database
    tz.initializeTimeZones();

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request OS permission (iOS + Android 13+)
    await requestPermission();

    // Setup local notifications channel (Android)
    await _setupLocalNotifications();

    // Handle foreground FCM messages
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Handle notification tap when app is in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);

    // Handle notification tap from terminated state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _onMessageOpened(initialMessage);
    }

    debugPrint('FcmService: Initialized successfully.');
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<void> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint(
        'FcmService: Permission status — ${settings.authorizationStatus}');

    if (!kIsWeb) {
      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      
      await _localNotif
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
    }
  }

  // ── Token Management ──────────────────────────────────────────────────────

  /// Returns the current FCM registration token for this device.
  /// Returns null if the user has not granted notification permission.
  Future<String?> getToken() async {
    try {
      // On web, pass the VAPID key; on mobile, no key is needed.
      final token = kIsWeb
          ? await _messaging.getToken(
              vapidKey: 'BOpZ3_a3HYwvDsXbIPLeyrYOBDujsg7nPkNARgvJSS9NRHDDmvhZScmfT56WOsBtNtIWZJKzI9j4KqORnoJKsEk', // Replace with actual VAPID key for web
            )
          : await _messaging.getToken();
      debugPrint('FcmService: FCM Token — $token');
      return token;
    } catch (e) {
      debugPrint('FcmService: Failed to get token — $e');
      return null;
    }
  }

  /// Listen for token refreshes and invoke [onRefresh] with the new token.
  void onTokenRefresh(void Function(String token) onRefresh) {
    _messaging.onTokenRefresh.listen(onRefresh);
  }

  // ── Topic Subscriptions ───────────────────────────────────────────────────

  /// Subscribes to a named FCM topic (e.g., 'daily_reminder').
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('FcmService: Subscribed to topic — $topic');
    } catch (e) {
      debugPrint('FcmService: Failed to subscribe to $topic — $e');
    }
  }

  /// Unsubscribes from a named FCM topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('FcmService: Unsubscribed from topic — $topic');
    } catch (e) {
      debugPrint('FcmService: Failed to unsubscribe from $topic — $e');
    }
  }

  /// Sync topic subscriptions based on current [NotificationSettingsModel].
  /// Call this after the user saves notification preferences.
  Future<void> syncTopics({
    required bool dailyReminder,
    required bool medicineReminder,
    required bool glucoseReminder,
    required bool riskPrediction,
  }) async {
    _syncTopic(topicDailyReminder, dailyReminder);
    _syncTopic(topicMedicineReminder, medicineReminder);
    _syncTopic(topicGlucoseReminder, glucoseReminder);
    _syncTopic(topicRiskPrediction, riskPrediction);
  }

  void _syncTopic(String topic, bool subscribe) {
    if (subscribe) {
      subscribeToTopic(topic);
    } else {
      unsubscribeFromTopic(topic);
    }
  }

  // ── Local Notifications Setup ─────────────────────────────────────────────

  Future<void> _setupLocalNotifications() async {
    // Android notification channel (required for Android 8+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Initialize local notifications plugin
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('notification_icon');

    const DarwinInitializationSettings iosInit =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );
  }

  // ── Foreground Message Handling ───────────────────────────────────────────

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('FcmService [FG]: Message — ${message.notification?.title}');
    final notification = message.notification;
    if (notification != null) {
      showLocalNotification(
        title: notification.title ?? 'DiaCare AI',
        body: notification.body ?? '',
        payload: message.data['route'],
      );
    }
  }

  void _onMessageOpened(RemoteMessage message) {
    debugPrint('FcmService: Notification tapped — ${message.data}');
    // TODO: Navigate to specific screen based on message.data['route']
    // This can be wired to a NavigationService or GlobalKey<NavigatorState>.
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    debugPrint('FcmService: Local notification tapped — ${response.payload}');
    // TODO: Handle navigation from local notification tap.
  }

  // ── Public Notification Display ───────────────────────────────────────────

  /// Shows an immediate local notification (useful for foreground FCM messages).
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    // Skip local notifications on web (not supported).
    if (kIsWeb) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      icon: 'notification_icon',
      largeIcon: DrawableResourceAndroidBitmap('notification_icon'),
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotif.show(id, title, body, details, payload: payload);
  }

  /// Cancels all pending local notifications.
  Future<void> cancelAllNotifications() async {
    await _localNotif.cancelAll();
  }

  // ── Scheduled Local Notifications ──────────────────────────────────────────

  tz.Location get _localLocation {
    try {
      return tz.getLocation('Asia/Jakarta');
    } catch (_) {
      return tz.UTC;
    }
  }

  /// Schedules a recurring daily notification at a specific time.
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required String timeString,
  }) async {
    if (kIsWeb) return;

    try {
      final parts = timeString.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final loc = _localLocation;
      final tz.TZDateTime now = tz.TZDateTime.now(loc);
      tz.TZDateTime scheduledDate = tz.TZDateTime(
        loc,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.max,
        icon: 'notification_icon',
        largeIcon: DrawableResourceAndroidBitmap('notification_icon'),
        playSound: true,
        enableVibration: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Cancel existing notification with the same ID first
      await _localNotif.cancel(id);

      await _localNotif.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('FcmService: Scheduled notification ID $id at $timeString ($scheduledDate)');
    } catch (e) {
      debugPrint('FcmService: Failed to schedule notification ID $id — $e');
    }
  }

  /// Synchronizes local schedules based on the user's current settings.
  Future<void> updateScheduledNotifications(NotificationSettingsModel settings) async {
    if (kIsWeb) return;

    // 1. Daily Reminder (ID 1)
    if (settings.dailyReminder) {
      await scheduleDailyNotification(
        id: 1,
        title: 'Pengingat Harian DiaCare ☀️',
        body: 'Jangan lupa untuk mencatat aktivitas dan memantau kondisi kesehatan Anda hari ini!',
        timeString: settings.dailyReminderTime,
      );
    } else {
      await _localNotif.cancel(1);
      debugPrint('FcmService: Cancelled daily reminder (ID 1)');
    }

    // 2. Medicine Reminder (ID 2)
    if (settings.medicineReminder) {
      await scheduleDailyNotification(
        id: 2,
        title: 'Pengingat Minum Obat 💊',
        body: 'Saatnya meminum obat Anda sesuai jadwal agar kesehatan tetap terjaga.',
        timeString: settings.medicineReminderTime,
      );
    } else {
      await _localNotif.cancel(2);
      debugPrint('FcmService: Cancelled medicine reminder (ID 2)');
    }

    // 3. Glucose Reminder (ID 3)
    if (settings.glucoseReminder) {
      await scheduleDailyNotification(
        id: 3,
        title: 'Pengingat Cek Gula Darah 🩸',
        body: 'Sudahkah Anda mengecek gula darah hari ini? Mari pantau kadar glukosa Anda.',
        timeString: settings.glucoseReminderTime,
      );
    } else {
      await _localNotif.cancel(3);
      debugPrint('FcmService: Cancelled glucose reminder (ID 3)');
    }
  }
}

