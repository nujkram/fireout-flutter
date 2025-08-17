import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fireout/config/app_config.dart';
import 'package:fireout/services/auth_service.dart';
import 'package:fireout/services/notification_service.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  
  final AuthService _authService = AuthService();
  NotificationService? _notificationService;
  
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  
  String get _webSocketUrl {
    final baseUrl = AppConfig.instance.baseUrl;
    // Convert HTTP(S) URL to WebSocket URL
    final wsUrl = baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://');
    return '$wsUrl/ws/incidents';
  }

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected || _isConnecting) {
      print('🔌 WebSocket already connected or connecting');
      return;
    }

    // Skip WebSocket connection on web for now (can be enabled later)
    if (kIsWeb) {
      print('🔌 WebSocket skipped on web platform');
      return;
    }

    _isConnecting = true;
    print('🔌 Connecting to WebSocket: $_webSocketUrl');

    try {
      final userId = await _authService.getUserId();
      final userRole = await _authService.getUserRole();
      final authToken = _authService.authToken;

      if (userId == null || userRole == null || authToken == null) {
        print('🚨 Cannot connect to WebSocket: User not authenticated');
        _isConnecting = false;
        return;
      }

      // Only connect for admin roles
      if (!['ADMINISTRATOR', 'MANAGER', 'OFFICER'].contains(userRole)) {
        print('🔌 WebSocket not needed for USER role');
        _isConnecting = false;
        return;
      }

      // Create WebSocket connection with authentication headers
      final uri = Uri.parse(_webSocketUrl);
      final headers = {
        'Authorization': 'Bearer $authToken',
        'X-User-ID': userId,
        'X-User-Role': userRole,
      };

      _channel = IOWebSocketChannel.connect(
        uri,
        headers: headers,
        pingInterval: _heartbeatInterval,
      );

      await _channel!.ready;

      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      
      print('🔌 WebSocket connected successfully');
      
      // Send initial ping to establish connection
      _sendHeartbeat();
      _startHeartbeat();

    } catch (e) {
      print('🚨 WebSocket connection failed: $e');
      _isConnected = false;
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic message) {
    try {
      print('🔌 WebSocket message received: $message');
      
      final data = jsonDecode(message.toString());
      final type = data['type'];
      
      switch (type) {
        case 'incident_status_update':
          _handleIncidentStatusUpdate(data);
          break;
        case 'new_incident':
          _handleNewIncident(data);
          break;
        case 'ping':
          _handlePing();
          break;
        case 'pong':
          print('🔌 Received pong from server');
          break;
        default:
          print('🔌 Unknown message type: $type');
      }
    } catch (e) {
      print('🚨 Error parsing WebSocket message: $e');
    }
  }

  void _handleIncidentStatusUpdate(Map<String, dynamic> data) async {
    try {
      final incidentId = data['incidentId']?.toString();
      final newStatus = data['status']?.toString();
      final incidentType = data['incidentType']?.toString();
      final location = data['location'];
      final description = data['description']?.toString();

      if (incidentId == null || newStatus == null || incidentType == null) {
        print('🚨 Invalid incident status update data');
        return;
      }

      print('🔔 Incident status update received: $incidentId -> $newStatus');
      
      // Initialize notification service if not already done
      _notificationService ??= NotificationService();
      
      // Trigger notification for the status change
      await _notificationService!.handleIncidentStatusChange(
        incidentId, 
        newStatus, 
        incidentType
      );
      
      // Also show a more detailed notification with location info
      await _showDetailedStatusUpdateNotification(
        incidentId, 
        newStatus, 
        incidentType, 
        location, 
        description
      );
      
    } catch (e) {
      print('🚨 Error handling incident status update: $e');
    }
  }

  void _handleNewIncident(Map<String, dynamic> data) async {
    try {
      final incidentId = data['incidentId']?.toString();
      final incidentType = data['incidentType']?.toString();
      final location = data['location'];
      final description = data['description']?.toString();

      if (incidentId == null || incidentType == null) {
        print('🚨 Invalid new incident data');
        return;
      }

      print('🔔 New incident received: $incidentId ($incidentType)');
      
      // Initialize notification service if not already done
      _notificationService ??= NotificationService();
      
      // Show notification for new incident
      await _showNewIncidentNotification(
        incidentId, 
        incidentType, 
        location, 
        description
      );
      
    } catch (e) {
      print('🚨 Error handling new incident: $e');
    }
  }

  void _handlePing() {
    print('🔌 Received ping from server, sending pong');
    _sendMessage({'type': 'pong'});
  }

  Future<void> _showDetailedStatusUpdateNotification(
    String incidentId, 
    String status, 
    String incidentType, 
    dynamic location, 
    String? description
  ) async {
    try {
      _notificationService ??= NotificationService();
      
      String locationText = 'Unknown location';
      if (location != null && location is Map) {
        final lat = location['latitude']?.toString();
        final lng = location['longitude']?.toString();
        if (lat != null && lng != null) {
          locationText = 'Lat: $lat, Lng: $lng';
        }
      }
      
      String title = 'Incident Update: $incidentType';
      String body = 'Status changed to $status';
      if (description != null && description.isNotEmpty) {
        body += '\n${description.length > 100 ? '${description.substring(0, 100)}...' : description}';
      }
      body += '\nLocation: $locationText';
      
      // Create a detailed remote message for notification
      final message = RemoteMessage(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        notification: RemoteNotification(
          title: title,
          body: body,
        ),
        data: {
          'incidentId': incidentId,
          'status': status,
          'incidentType': incidentType,
          'source': 'websocket',
        },
      );
      
      await _notificationService!.showLocalNotification(message);
      
    } catch (e) {
      print('🚨 Error showing detailed status update notification: $e');
    }
  }

  Future<void> _showNewIncidentNotification(
    String incidentId, 
    String incidentType, 
    dynamic location, 
    String? description
  ) async {
    try {
      _notificationService ??= NotificationService();
      
      String locationText = 'Unknown location';
      if (location != null && location is Map) {
        final lat = location['latitude']?.toString();
        final lng = location['longitude']?.toString();
        if (lat != null && lng != null) {
          locationText = 'Lat: $lat, Lng: $lng';
        }
      }
      
      String title = 'New Incident: $incidentType';
      String body = 'A new incident has been reported';
      if (description != null && description.isNotEmpty) {
        body += '\n${description.length > 100 ? '${description.substring(0, 100)}...' : description}';
      }
      body += '\nLocation: $locationText';
      
      // Create a detailed remote message for notification
      final message = RemoteMessage(
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        notification: RemoteNotification(
          title: title,
          body: body,
        ),
        data: {
          'incidentId': incidentId,
          'status': 'NEW',
          'incidentType': incidentType,
          'source': 'websocket',
        },
      );
      
      await _notificationService!.showLocalNotification(message);
      
    } catch (e) {
      print('🚨 Error showing new incident notification: $e');
    }
  }

  void _handleError(error) {
    print('🚨 WebSocket error: $error');
    _isConnected = false;
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    print('🔌 WebSocket disconnected');
    _isConnected = false;
    _stopHeartbeat();
    
    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('🚨 Max reconnect attempts reached, giving up');
      return;
    }

    _reconnectAttempts++;
    print('🔌 Scheduling reconnect attempt $_reconnectAttempts in ${_reconnectDelay.inSeconds} seconds');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_shouldReconnect && !_isConnected) {
        connect();
      }
    });
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_isConnected) {
        _sendHeartbeat();
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _sendHeartbeat() {
    _sendMessage({'type': 'ping', 'timestamp': DateTime.now().millisecondsSinceEpoch});
  }

  void _sendMessage(Map<String, dynamic> message) {
    if (!_isConnected || _channel == null) {
      print('🚨 Cannot send message: WebSocket not connected');
      return;
    }

    try {
      final messageStr = jsonEncode(message);
      _channel!.sink.add(messageStr);
      print('🔌 Message sent: $messageStr');
    } catch (e) {
      print('🚨 Error sending message: $e');
    }
  }

  Future<void> disconnect() async {
    print('🔌 Disconnecting WebSocket');
    
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    
    await _subscription?.cancel();
    await _channel?.sink.close();
    
    _channel = null;
    _subscription = null;
    _isConnected = false;
    _isConnecting = false;
    _reconnectAttempts = 0;
  }

  void setNotificationService(NotificationService notificationService) {
    _notificationService = notificationService;
  }

  // Method to manually reconnect (can be called from UI)
  Future<void> reconnect() async {
    await disconnect();
    _shouldReconnect = true;
    await connect();
  }
}