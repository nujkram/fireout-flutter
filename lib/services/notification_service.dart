import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:fireout/config/app_config.dart';
import 'package:fireout/services/auth_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final Dio _dio = Dio();
  final AuthService _authService = AuthService();
  // Removed unused _initialized flag

  String get baseUrl => AppConfig.instance.baseUrl;

  Future<void> initialize() async {
    print('🔔 Initializing notification service...');
    
    try {
      // Ensure Firebase is initialized by caller (main.dart)
      if (Firebase.apps.isEmpty) {
        throw Exception('Firebase is not initialized');
      }

      _firebaseMessaging = FirebaseMessaging.instance;

      // Initialize local notifications
      await _initializeLocalNotifications();
      print('🔔 Local notifications initialized');

      // Request permissions
      await _requestPermissions();
      print('🔔 Notification permissions requested');

      // Get FCM token
      await _getFCMToken();
      print('🔔 FCM token obtained');

      // Set up message handlers
      _setupMessageHandlers();
      print('🔔 Message handlers set up');

      print('🔔 Notification service initialized successfully');
    } catch (e) {
      print('🚨 Error initializing notification service: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    if (!kIsWeb) {
      const androidChannel = AndroidNotificationChannel(
        'incident_updates',
        'Incident Updates',
        description: 'Notifications for incident status changes',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
  }

  Future<void> _requestPermissions() async {
    // Request FCM permissions
    if (_firebaseMessaging == null) return;
    NotificationSettings settings = await _firebaseMessaging!.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('🔔 FCM permission status: ${settings.authorizationStatus}');

    // Request local notification permissions for iOS
    if (!kIsWeb) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  Future<String?> _getFCMToken() async {
    try {
      if (_firebaseMessaging == null) return null;
      String? token = await _firebaseMessaging!.getToken();
      print('🔔 FCM Token: $token');
      
      if (token != null) {
        // Register token with backend
        await _registerTokenWithBackend(token);
      }
      
      return token;
    } catch (e) {
      print('🚨 Error getting FCM token: $e');
      return null;
    }
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      final userId = await _authService.getUserId();
      final userRole = await _authService.getUserRole();
      
      if (userId == null || userRole == null) {
        print('🚨 Cannot register FCM token: User not authenticated');
        return;
      }

      // Only register tokens for admin roles
      if (!['ADMINISTRATOR', 'MANAGER', 'OFFICER'].contains(userRole)) {
        print('🔔 Skipping FCM token registration for USER role');
        return;
      }

      final response = await _dio.post(
        '$baseUrl/api/notifications/register-token',
        data: {
          'userId': userId,
          'role': userRole,
          'fcmToken': token,
          'platform': kIsWeb ? 'web' : 'mobile',
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (_authService.authToken != null)
              'Authorization': 'Bearer ${_authService.authToken}',
          },
        ),
      );

      if (response.statusCode == 200) {
        print('🔔 FCM token registered successfully with backend');
      } else {
        print('🚨 Failed to register FCM token: ${response.statusCode}');
      }
    } catch (e) {
      print('🚨 Error registering FCM token with backend: $e');
    }
  }

  void _setupMessageHandlers() {
    if (_firebaseMessaging == null) return;
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tapped when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTapped);

    // Handle initial message when app is launched from terminated state
    _handleInitialMessage();

    // Handle token refresh
    _firebaseMessaging!.onTokenRefresh.listen((newToken) {
      print('🔔 FCM token refreshed: $newToken');
      _registerTokenWithBackend(newToken);
    });
  }

  Future<void> _handleInitialMessage() async {
    if (_firebaseMessaging == null) return;
    RemoteMessage? initialMessage = await _firebaseMessaging!.getInitialMessage();
    if (initialMessage != null) {
      print('🔔 App launched from notification: ${initialMessage.messageId}');
      _handleNotificationTapped(initialMessage);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('🔔 Received message in foreground: ${message.messageId}');
    print('🔔 Message data: ${message.data}');

    // Show local notification when app is in foreground
    if (message.notification != null) {
      await _showLocalNotification(message);
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'incident_updates',
      'Incident Updates',
      channelDescription: 'Notifications for incident status changes',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? 'Incident Update',
      message.notification?.body ?? 'An incident status has changed',
      notificationDetails,
      payload: message.data['incidentId'],
    );
  }

  void _handleNotificationTapped(RemoteMessage message) {
    print('🔔 Notification tapped: ${message.messageId}');
    print('🔔 Message data: ${message.data}');

    // Navigate to incident detail screen if incidentId is provided
    final incidentId = message.data['incidentId'];
    if (incidentId != null && incidentId.isNotEmpty) {
      _navigateToIncidentDetail(incidentId);
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('🔔 Local notification tapped: ${response.payload}');
    
    if (response.payload != null && response.payload!.isNotEmpty) {
      _navigateToIncidentDetail(response.payload!);
    }
  }

  void _navigateToIncidentDetail(String incidentId) {
    // TODO: Implement navigation to incident detail screen
    // This would typically use Navigator or your app's routing system
    print('🔔 Navigate to incident detail: $incidentId');
  }

  // Method to be called when user logs out
  Future<void> clearToken() async {
    try {
      if (_firebaseMessaging == null) return;
      await _firebaseMessaging!.deleteToken();
      print('🔔 FCM token cleared');
    } catch (e) {
      print('🚨 Error clearing FCM token: $e');
    }
  }

  // Method to refresh token manually
  Future<void> refreshToken() async {
    try {
      if (_firebaseMessaging == null) return;
      String? token = await _firebaseMessaging!.getToken();
      if (token != null) {
        await _registerTokenWithBackend(token);
      }
    } catch (e) {
      print('🚨 Error refreshing FCM token: $e');
    }
  }
}