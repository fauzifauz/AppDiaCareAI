import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/health_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/privacy_provider.dart';
import 'providers/support_provider.dart';
import 'repositories/database_repository.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'services/fcm_service.dart';
import 'services/tflite_prediction_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize FCM after Firebase is ready
    await FcmService.instance.initialize();

    // Request OS notification permission at the very start of app launch
    await FcmService.instance.requestPermission();

    // Initialize TFLite model
    await TflitePredictionService().initModel();
  } catch (e) {
    debugPrint('Firebase or TFLite initialization failed: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HealthProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => PrivacyProvider()),
        ChangeNotifierProvider(create: (_) => SupportProvider()),
      ],
      child: const DiaCareApp(),
    ),
  );
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class DiaCareApp extends StatelessWidget {
  const DiaCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'DiaCare AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.isAuthenticated) {
      if (authProvider.firebaseUser!.emailVerified) {
        final uid = authProvider.firebaseUser!.uid;
        // Initialize all provider streams inside post frame callback
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          context.read<HealthProvider>().initialize(uid);
          context.read<NotificationProvider>().initialize(uid);
          context.read<PrivacyProvider>().initialize(uid);

          // Save initial FCM token on startup
          final token = await FcmService.instance.getToken();
          if (token != null) {
            await DatabaseRepository().saveFcmToken(uid, token);
            debugPrint('AuthWrapper: Initial FCM token saved for $uid');
          }

          // Keep FCM token up-to-date when Firebase rotates the device token
          FcmService.instance.onTokenRefresh((newToken) {
            final dbRepo = DatabaseRepository();
            dbRepo.saveFcmToken(uid, newToken);
            debugPrint('AuthWrapper: FCM token rotated & saved for $uid');
          });
        });
        return const DashboardScreen();
      } else {
        return const VerifyEmailScreen();
      }
    }

    return const SplashScreen();
  }
}
