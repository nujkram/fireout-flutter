import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  
  // Track initialization state
  bool _isInitialized = false;
  bool _isInitializing = false;
  
  // Navigation context for routing
  static BuildContext? _navigationContext;

  String get baseUrl => AppConfig.instance.baseUrl;

  Future<void> initialize() async {
    // Prevent multiple simultaneous initializations
    if (_isInitialized) {
      print('🔔 Notification service already initialized');
      return;
    }
    
    if (_isInitializing) {
      print('🔔 Notification service initialization in progress, waiting...');
      // Wait for ongoing initialization to complete
      int attempts = 0;
      while (_isInitializing && attempts < 50) { // Wait max 5 seconds
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      return;
    }
    
    _isInitializing = true;
    print('🔔 Initializing notification service...');
    
    try {
      // Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        print('🚨 Firebase is not initialized, skipping FCM setup');
        // Continue with local notifications only
      } else {
        _firebaseMessaging = FirebaseMessaging.instance;
        
        // Get FCM token
        await _getFCMToken();
        print('🔔 FCM token obtained');

        // Set up message handlers'sound': kIsWeb ? null : const RawResourceAndroidNotificationSound('fire_alert'),
        _setupMessageHandlers();
        print('🔔 Message handlers set up');
      }

      // Initialize local notifications (always do this)
      await _initializeLocalNotifications();
      print('🔔 Local notifications initialized');

      // Request permissions
      await _requestPermissions();
      print('🔔 Notification permissions requested');

      _isInitialized = true;
      print('🔔 Notification service initialized successfully');
    } catch (e) {
      print('🚨 Error initializing notification service: $e');
      // Don't set _isInitialized = true on error, allow retry
    } finally {
      _isInitializing = false;
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

    // Create notification channels for Android with custom sounds (skip on web)
    if (!kIsWeb) {
      try {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      // General incident updates channel with custom sound
      const generalChannel = AndroidNotificationChannel(
        'incident_updates',
        'Incident Updates',
        description: 'General incident notifications',
        importance: Importance.max, // Max importance for sound
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('general_alert'), // Add sound to channel
      );

      // Fire emergency channel
      const fireChannel = AndroidNotificationChannel(
        'fire_incidents',
        'Fire Emergency',
        description: 'Fire emergency notifications with custom sound',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('fire_alert'),
      );

      // Medical emergency channel
      const medicalChannel = AndroidNotificationChannel(
        'medical_incidents',
        'Medical Emergency',
        description: 'Medical emergency notifications with custom sound',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('medical_alert'),
      );

      // Accident emergency channel
      const accidentChannel = AndroidNotificationChannel(
        'accident_incidents',
        'Accident Emergency',
        description: 'Accident emergency notifications with custom sound',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('accident_alert'),
      );
        
        // Delete existing channels first to force recreation with sound
        try {
          await androidPlugin?.deleteNotificationChannel('incident_updates');
          await androidPlugin?.deleteNotificationChannel('fire_incidents');
          await androidPlugin?.deleteNotificationChannel('medical_incidents');
          await androidPlugin?.deleteNotificationChannel('accident_incidents');
        } catch (e) {
          print('🔔 Old channels not found (expected): $e');
        }
        
        // Create channels with sound
        await androidPlugin?.createNotificationChannel(generalChannel);
        await androidPlugin?.createNotificationChannel(fireChannel);
        await androidPlugin?.createNotificationChannel(medicalChannel);
        await androidPlugin?.createNotificationChannel(accidentChannel);
        
        print('🔔 Android notification channels created successfully');
      } catch (e) {
        print('🚨 Error creating notification channels: $e');
      }
    } else {
      print('🔔 Web platform detected, skipping Android notification channels');
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
      final stationId = await _authService.getStationId();
      
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
          'stationId': stationId,
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
    // Always show a local notification in foreground, even for data-only messages
    // This ensures dashboard-triggered pushes (often data-only) still alert the user
    await showLocalNotification(message);
  }

  Future<void> showLocalNotification(RemoteMessage message) async {
    // Determine incident type and channel
    final incidentType = message.data['incidentType']?.toString().toLowerCase() ?? 'general';
    final channelConfig = _getChannelConfigForIncidentType(incidentType);
    
    final androidDetails = AndroidNotificationDetails(
      channelConfig['channelId'],
      channelConfig['channelName'],
      channelDescription: channelConfig['description'],
      importance: channelConfig['importance'],
      priority: channelConfig['priority'],
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      sound: channelConfig['sound'], // Custom sound for Android (null on web)
      enableVibration: !kIsWeb && channelConfig['vibration'] != null,
      vibrationPattern: channelConfig['vibration'], // Will be null on web
      fullScreenIntent: channelConfig['fullScreen'] && !kIsWeb,
      largeIcon: kIsWeb ? null : const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(
        message.notification?.body ?? 'An incident status has changed',
        htmlFormatBigText: false,
        contentTitle: message.notification?.title ?? 'Incident Update',
        htmlFormatContentTitle: false,
      ),
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: channelConfig['iosSound'], // Custom sound for iOS
      interruptionLevel: channelConfig['interruptionLevel'],
    );

    final notificationDetails = NotificationDetails(
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
    
    print('🔔 Notification shown with ${channelConfig['channelName']} sound for $incidentType incident');
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

  // Helper method to get channel configuration based on incident type
  Map<String, dynamic> _getChannelConfigForIncidentType(String incidentType) {
    // Create vibration patterns only for non-web platforms
    Int64List? createVibrationPattern(List<int> pattern) {
      if (kIsWeb) return null; // Web doesn't support vibration patterns
      try {
        return Int64List.fromList(pattern);
      } catch (e) {
        print('🚨 Error creating vibration pattern: $e');
        return null;
      }
    }

    switch (incidentType.toLowerCase()) {
      case 'fire':
        return {
          'channelId': 'fire_incidents',
          'channelName': 'Fire Emergency',
          'description': 'Fire emergency notifications',
          'importance': Importance.max,
          'priority': Priority.max,
          'sound': kIsWeb ? null : const RawResourceAndroidNotificationSound('fire_alert'), // Use system default for now
          'iosSound': 'fire_alert.mp3',
          'vibration': createVibrationPattern([0, 1000, 500, 1000, 500, 1000]), // Strong vibration pattern
          'fullScreen': !kIsWeb, // Web doesn't support full-screen notifications
          'interruptionLevel': InterruptionLevel.critical,
        };
      case 'medical':
      case 'medical emergency':
        return {
          'channelId': 'medical_incidents',
          'channelName': 'Medical Emergency',
          'description': 'Medical emergency notifications',
          'importance': Importance.max,
          'priority': Priority.max,
          'sound': kIsWeb ? null : const RawResourceAndroidNotificationSound('medical_alert'), // Use system default for now
          'iosSound': 'medical_alert.mp3',
          'vibration': createVibrationPattern([0, 800, 200, 800, 200, 800]), // Medical pattern
          'fullScreen': !kIsWeb,
          'interruptionLevel': InterruptionLevel.critical,
        };
      case 'accident':
      case 'traffic accident':
        return {
          'channelId': 'accident_incidents',
          'channelName': 'Accident Emergency',
          'description': 'Accident emergency notifications',
          'importance': Importance.max,
          'priority': Priority.max,
          'sound': kIsWeb ? null : const RawResourceAndroidNotificationSound('accident_alert'), // Use system default for now
          'iosSound': 'accident_alert.mp3',
          'vibration': createVibrationPattern([0, 600, 300, 600, 300, 600]), // Accident pattern
          'fullScreen': !kIsWeb,
          'interruptionLevel': InterruptionLevel.critical,
        };
      default:
        return {
          'channelId': 'incident_updates',
          'channelName': 'Incident Updates',
          'description': 'General incident notifications',
          'importance': Importance.high,
          'priority': Priority.high,
          'sound': kIsWeb ? null : const RawResourceAndroidNotificationSound('general_alert'), // Use system default for now
          'iosSound': 'general_alert.mp3',
          'vibration': createVibrationPattern([0, 500, 250, 500]), // Standard pattern
          'fullScreen': false,
          'interruptionLevel': InterruptionLevel.timeSensitive,
        };
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('🔔 Local notification tapped: ${response.payload}');
    
    if (response.payload != null && response.payload!.isNotEmpty) {
      _navigateToIncidentDetail(response.payload!);
    }
  }

  void _navigateToIncidentDetail(String incidentId) async {
    print('🔔 Navigate to incident detail: $incidentId');
    
    if (_navigationContext != null && _navigationContext!.mounted) {
      try {
        // Navigate to dashboard where they can find the incident
        // This avoids the circular dependency with IncidentService
        Navigator.of(_navigationContext!).pushNamedAndRemoveUntil(
          '/main',
          (Route<dynamic> route) => false,
        );
        print('🔔 Successfully navigated to dashboard');
      } catch (e) {
        print('🚨 Error navigating: $e');
      }
    } else {
      print('🚨 Navigation context not available');
    }
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
  
  // Static method to set navigation context from the app
  static void setNavigationContext(BuildContext context) {
    _navigationContext = context;
  }
  
  // Static method to clear navigation context
  static void clearNavigationContext() {
    _navigationContext = null;
  }
  
  
  // Method to handle incident status change (called from incident service)
  Future<void> handleIncidentStatusChange(String incidentId, String newStatus, String incidentType) async {
    if (newStatus == 'IN-PROGRESS') {
      print('🔔 Incident $incidentId changed to IN-PROGRESS, preparing notification');
      
      // This would typically be called from the backend, but we can also
      // trigger local notifications for immediate feedback
      final message = RemoteMessage(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        notification: RemoteNotification(
          title: 'Incident Update: $incidentType',
          body: 'An incident has been updated to IN-PROGRESS status',
        ),
        data: {
          'incidentId': incidentId,
          'status': newStatus,
          'incidentType': incidentType,
        },
      );
      
      await showLocalNotification(message);
    }
  }

  // Enhanced method to handle station-based incident notifications with alert levels
  Future<void> handleStationIncidentNotification({
    required String incidentId,
    required String stationId,
    required String incidentType,
    required String status,
    required String alertLevel, // '1st', '2nd', '3rd'
    String? description,
    Map<String, double>? location,
  }) async {
    try {
      final userId = await _authService.getUserId();
      final userRole = await _authService.getUserRole();
      final userStationId = await _authService.getStationId();
      
      if (userId == null || userRole == null) {
        print('🚨 Cannot send station notification: User not authenticated');
        return;
      }

      // Only send notifications to responders (not regular users)
      if (!['ADMINISTRATOR', 'MANAGER', 'OFFICER'].contains(userRole)) {
        return;
      }

      // Check if this user should receive notifications for this incident
      if (userStationId != stationId) {
        print('🔔 Skipping notification: User station ($userStationId) != incident station ($stationId)');
        return;
      }

      // Create notification based on alert level
      String title;
      String body;
      
      switch (alertLevel.toLowerCase()) {
        case '1st':
          title = '🚨 URGENT: $incidentType - 1st Responder Alert';
          body = 'Immediate response required at ${description ?? 'incident location'}';
          break;
        case '2nd':
          title = '⚠️ BACKUP: $incidentType - 2nd Responder Alert';
          body = 'Backup response requested for ongoing incident';
          break;
        case '3rd':
          title = '📢 SUPPORT: $incidentType - 3rd Responder Alert';
          body = 'Additional support needed for incident escalation';
          break;
        default:
          title = '🔔 Incident Update: $incidentType';
          body = 'Status: $status';
      }

      final message = RemoteMessage(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        notification: RemoteNotification(
          title: title,
          body: body,
        ),
        data: {
          'incidentId': incidentId,
          'stationId': stationId,
          'incidentType': incidentType,
          'status': status,
          'alertLevel': alertLevel,
          'description': description ?? '',
          if (location != null) 'latitude': location['latitude'].toString(),
          if (location != null) 'longitude': location['longitude'].toString(),
        },
      );
      
      await showLocalNotification(message);
      print('🔔 Station-based notification sent for $alertLevel responder alert');
      
    } catch (e) {
      print('🚨 Error sending station incident notification: $e');
    }
  }
}