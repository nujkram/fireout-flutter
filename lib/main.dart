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
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
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

// Background message handler (must be top-level function)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 Background message received: ${message.messageId}');
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
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (e) {
    // On web, Firebase initialization requires options configured via FlutterFire.
    // If not configured, skip notifications setup gracefully.
    // ignore: avoid_print
    print('🚨 Firebase initialization failed or not configured for this platform: $e');
  }

  // Initialize auth service
  final authService = AuthService();
  authService.setupCookieManager();
  await authService.initializeAuth();
  
  // Initialize notification service (only if Firebase is ready)
  if (firebaseReady) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    final notificationService = NotificationService();
    await notificationService.initialize();
  }
  
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
