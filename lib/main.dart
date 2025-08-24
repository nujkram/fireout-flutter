import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:fireout/config/app_config.dart';
import 'package:fireout/cubit/bottom_nav_cubit.dart';
import 'package:fireout/cubit/theme_cubit.dart';
import 'package:fireout/services/auth_service.dart';
import 'package:fireout/services/notification_service.dart';
import 'package:fireout/services/websocket_service.dart';
import 'package:fireout/services/native_permissions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fireout/ui/screens/auth_wrapper.dart';
import 'package:fireout/ui/screens/login/login_screen.dart';
import 'package:fireout/ui/screens/incident/incident_detail_screen.dart';
import 'package:fireout/ui/screens/role_based_main_screen.dart';
import 'package:fireout/ui/screens/user/user_dashboard_screen.dart';
import 'package:fireout/ui/screens/user/report_incident_screen.dart';
import 'package:fireout/ui/screens/user/user_incident_history_screen.dart';
import 'package:fireout/ui/screens/user/user_incident_detail_screen.dart';
import 'package:fireout/ui/screens/dashboard/dashboard_screen.dart';
import 'package:fireout/ui/screens/profile/profile_screen.dart';
import 'package:fireout/ui/widgets/role_guard_route.dart';
import 'package:fireout/user_dashboard.dart';
import 'package:fireout/ui/screens/auth/phone_signup_screen.dart';
import 'package:fireout/ui/screens/auth/otp_verification_screen.dart';

// Background message handler (must be top-level function)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure plugins are ready in background isolate
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}

  print('🔔 Background message received: ${message.messageId}');
  // Build and show a local notification for data-only messages
  try {
    final incidentTypeRaw = (message.data['incidentType'] ?? 'general').toString().toLowerCase();
    String channelId = 'incident_updates';
    String channelName = 'Incident Updates';
    String iosSound = 'general_alert.mp3';
    AndroidNotificationSound? androidSound = const RawResourceAndroidNotificationSound('general_alert');
    Int64List? vibration;

    Int64List? vib(List<int> pts) {
      try { return Int64List.fromList(pts); } catch (_) { return null; }
    }

    switch (incidentTypeRaw) {
      case 'fire':
        channelId = 'fire_incidents';
        channelName = 'Fire Emergency';
        androidSound = const RawResourceAndroidNotificationSound('fire_alert');
        iosSound = 'fire_alert.mp3';
        vibration = vib([0, 1000, 500, 1000, 500, 1000]);
        break;
      case 'medical':
      case 'medical emergency':
        channelId = 'medical_incidents';
        channelName = 'Medical Emergency';
        androidSound = const RawResourceAndroidNotificationSound('medical_alert');
        iosSound = 'medical_alert.mp3';
        vibration = vib([0, 800, 200, 800, 200, 800]);
        break;
      case 'accident':
      case 'traffic accident':
        channelId = 'accident_incidents';
        channelName = 'Accident Emergency';
        androidSound = const RawResourceAndroidNotificationSound('accident_alert');
        iosSound = 'accident_alert.mp3';
        vibration = vib([0, 600, 300, 600, 300, 600]);
        break;
      default:
        // Keep defaults
        vibration = vib([0, 500, 250, 500]);
    }

    final plugin = FlutterLocalNotificationsPlugin();

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Incident notification',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      sound: androidSound,
      enableVibration: true,
      vibrationPattern: vibration,
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: iosSound,
      interruptionLevel: InterruptionLevel.critical,
    );
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final title = message.notification?.title ?? (message.data['title'] as String?) ?? 'Incident Update';
    final body = message.notification?.body ?? (message.data['body'] as String?) ?? 'An incident status has changed';

    await plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: message.data['incidentId'] as String?,
    );
  } catch (e) {
    // ignore: avoid_print
    print('🚨 Error showing background notification: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize configuration based on flavor
  AppConfig.initialize();
  
  try {
    if (!kIsWeb && Platform.isAndroid) {
      await FlutterDisplayMode.setHighRefreshRate();
    }
  } catch (e) {
    // Platform check not supported on web
  }
  
  // Initialize Firebase BEFORE any Firebase Messaging usage
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
    print('✅ Firebase initialized successfully');
  } catch (e) {
    // On web, Firebase initialization requires options configured via FlutterFire.
    // If not configured, skip notifications setup gracefully.
    // ignore: avoid_print
    print('🚨 Firebase initialization failed or not configured for this platform: $e');
    // Don't crash the app, just continue without Firebase features
  }

  // Initialize auth service
  final authService = AuthService();
  authService.setupCookieManager();
  await authService.initializeAuth();
  
  // Initialize notification service (only if Firebase is ready)
  if (firebaseReady) {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      final notificationService = NotificationService();
      await notificationService.initialize();
      print('✅ Notification service initialized successfully');
      
      // Initialize WebSocket service for real-time updates
      try {
        final webSocketService = WebSocketService();
        webSocketService.setNotificationService(notificationService);
        await webSocketService.connect();
        print('✅ WebSocket service initialized successfully');
      } catch (e) {
        print('🚨 WebSocket service initialization failed: $e');
        // Don't crash the app, WebSocket is not critical for basic functionality
      }
    } catch (e) {
      print('🚨 Notification service initialization failed: $e');
      // Don't crash the app, continue without notifications
    }
  }

  // Start Android reminder service to help users enable permissions if blocked
  try {
    if (!kIsWeb && Platform.isAndroid) {
      await NativePermissions.startPermissionReminderService();
    }
  } catch (_) {}
  
  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: kIsWeb
        ? HydratedStorageDirectory.web
        : HydratedStorageDirectory((await getTemporaryDirectory()).path),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeCubit>(
          create: (context) => ThemeCubit(),
        ),
        BlocProvider<BottomNavCubit>(
          create: (context) => BottomNavCubit(),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, state) {
          return MaterialApp(
            title: AppConfig.instance.appName,
            theme: state.themeData,
            home: const AuthWrapper(),
            debugShowCheckedModeBanner: AppConfig.instance.debugMode,
            routes: {
              '/login': (context) => const LoginScreen(),
              '/phone-signup': (context) => const PhoneSignupScreen(),
              '/otp-verification': (context) => const OTPVerificationScreen(),
              
              // Role-based main routes
              '/main': (context) => const RoleBasedMainScreen(),
              
              // USER role routes
              '/user-dashboard': (context) => RoleGuardRoute(
                allowedRoles: const ['USER'],
                child: const UserDashboardScreen(),
              ),
              '/report-incident': (context) => RoleGuardRoute(
                allowedRoles: const ['USER'],
                child: const ReportIncidentScreen(),
              ),
              '/user-incident-history': (context) => RoleGuardRoute(
                allowedRoles: const ['USER'],
                child: const UserIncidentHistoryScreen(),
              ),
              
              // OFFICER+ role routes
              '/dashboard': (context) => RoleGuardRoute(
                allowedRoles: const ['OFFICER', 'MANAGER', 'ADMINISTRATOR'],
                child: const DashboardScreen(),
              ),
              
              // Profile route (accessible to all authenticated users)
              '/profile': (context) => RoleGuardRoute(
                allowedRoles: const ['USER', 'OFFICER', 'MANAGER', 'ADMINISTRATOR'],
                child: const ProfileScreen(),
              ),
              
              // Legacy route for compatibility
              '/old-dashboard': (context) => const UserDashboard(),
            },
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/incident-detail':
                  final incident = settings.arguments as Map<String, dynamic>;
                  return MaterialPageRoute(
                    builder: (context) => RoleGuardRoute(
                      allowedRoles: const ['OFFICER', 'MANAGER', 'ADMINISTRATOR'],
                      child: IncidentDetailScreen(incident: incident),
                    ),
                  );
                case '/user-incident-detail':
                  final incident = settings.arguments as Map<String, dynamic>;
                  return MaterialPageRoute(
                    builder: (context) => RoleGuardRoute(
                      allowedRoles: const ['USER'],
                      child: UserIncidentDetailScreen(incident: incident),
                    ),
                  );
                default:
                  return null;
              }
            },
          );
        },
      ),
    );
  }
}
