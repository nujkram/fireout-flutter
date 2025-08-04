import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:fireout/config/app_config.dart';
import 'package:fireout/cubit/bottom_nav_cubit.dart';
import 'package:fireout/cubit/theme_cubit.dart';
import 'package:fireout/services/auth_service.dart';
import 'package:hive/hive.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fireout/ui/screens/login/login_screen.dart';
import 'package:fireout/ui/screens/incident/incident_detail_screen.dart';
import 'package:fireout/user_dashboard.dart';

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
  
  // Initialize auth service
  await AuthService().initializeAuth();
  
  late HydratedStorage storage;
  if (kIsWeb) {
    storage = await HydratedStorage.build(
      storageDirectory: HydratedStorage.webStorageDirectory,
    );
  } else {
    final tmpDir = await getTemporaryDirectory();
    Hive.init(tmpDir.toString());
    storage = await HydratedStorage.build(
      storageDirectory: tmpDir,
    );
  }

  HydratedBlocOverrides.runZoned(
    () => runApp(const MyApp()),
    storage: storage,
  );
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
            home: const LoginScreen(),
            debugShowCheckedModeBanner: AppConfig.instance.debugMode,
            routes: {
              '/login': (context) => const LoginScreen(),
              '/dashboard': (context) => const UserDashboard(),
            },
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/incident-detail':
                  final incident = settings.arguments as Map<String, dynamic>;
                  return MaterialPageRoute(
                    builder: (context) => IncidentDetailScreen(incident: incident),
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
