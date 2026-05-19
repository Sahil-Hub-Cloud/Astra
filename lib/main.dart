import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/error_handler.dart';
import 'core/services/notification_service.dart';
import 'core/services/danger_zone_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final notification = message.notification;
  if (notification != null) {
    await NotificationService.showLocalNotification(
      notification.title ?? 'Emergency Alert',
      notification.body ?? 'Emergency SOS detected nearby',
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  final supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Error: SUPABASE_URL and SUPABASE_ANON_KEY must be set.\n\n'
            'Run with: flutter run '
            '--dart-define=SUPABASE_URL=your_url '
            '--dart-define=SUPABASE_ANON_KEY=your_key',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ));
    return;
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  // Initialize Firebase and notification service
  await NotificationService().initialize();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Danger Zone monitoring
  DangerZoneService().startProactiveMonitoring();

  // Set up global error handler
  FlutterError.onError = (details) {
    ErrorHandler().handleFlutterError(details);
    FlutterError.dumpErrorToConsole(details);
  };

  runApp(const AstraEmergencyApp());
}

class AstraEmergencyApp extends StatelessWidget {
  const AstraEmergencyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Astra Emergency Network',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: goRouter,
      scaffoldMessengerKey: ErrorHandler().scaffoldMessengerKey,
    );
  }
}
