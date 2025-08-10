import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:fireout/config/app_config.dart';
import 'package:fireout/services/auth_service.dart';
import 'package:fireout/services/notification_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';

class IncidentService {
  static final IncidentService _instance = IncidentService._internal();
  factory IncidentService() => _instance;
  IncidentService._internal() {
    _setupDio();
  }

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));
  
  final AuthService _authService = AuthService();
  NotificationService? _notificationService;
  String get baseUrl => AppConfig.instance.baseUrl;

  void _setupDio() {
    if (!kIsWeb) {
      _dio.interceptors.add(CookieManager(CookieJar()));
    }
  }

  Future<List<Map<String, dynamic>>> getInProgressIncidents() async {
    try {
      print('🔍 Fetching in-progress incidents from: $baseUrl/api/admin/incident/in-progress');
      
      final userId = await _authService.getUserId();
      
      final response = await _dio.get(
        '$baseUrl/api/admin/incident/in-progress',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (_authService.authToken != null)
              'Authorization': 'Bearer ${_authService.authToken}',
            if (userId != null)
              'X-User-ID': userId,
          },
        ),
      );

      print('✅ Incidents response status: ${response.statusCode}');
      print('✅ Incidents response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data) 
            : response.data;
        
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['response'] != null) {
          return List<Map<String, dynamic>>.from(data['response']);
        } else if (data is Map && data['incidents'] != null) {
          return List<Map<String, dynamic>>.from(data['incidents']);
        }
      }
      
      return [];
    } catch (e) {
      print('🚨 Error fetching incidents: $e');
      if (e is DioException) {
        print('🚨 Dio error type: ${e.type}');
        print('🚨 Dio message: ${e.message}');
        print('🚨 Response data: ${e.response?.data}');
      }
      
      // Return mock data for now
      return _getMockIncidents();
    }
  }

  Future<Map<String, dynamic>?> getIncidentById(String incidentId) async {
    try {
      final userId = await _authService.getUserId();
      
      final response = await _dio.get(
        '$baseUrl/api/admin/incident/$incidentId',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (_authService.authToken != null)
              'Authorization': 'Bearer ${_authService.authToken}',
            if (userId != null)
              'X-User-ID': userId,
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data) 
            : response.data;
        return data;
      }
      
      return null;
    } catch (e) {
      print('🚨 Error fetching incident details: $e');
      return null;
    }
  }

  Future<bool> updateIncidentStatus(String incidentId, String status) async {
    try {
      final userId = await _authService.getUserId();
      
      // Get incident details before updating to extract type for notification
      Map<String, dynamic>? incident;
      try {
        incident = await getIncidentById(incidentId);
      } catch (e) {
        print('🚨 Could not fetch incident details for notification: $e');
      }
      
      final response = await _dio.put(
        '$baseUrl/api/admin/incident/$incidentId/status',
        data: jsonEncode({
          'status': status,
        }),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (_authService.authToken != null)
              'Authorization': 'Bearer ${_authService.authToken}',
            if (userId != null)
              'X-User-ID': userId,
          },
        ),
      );

      final success = response.statusCode == 200;
      
      // If status update was successful and status is IN-PROGRESS, trigger notification
      if (success && status == 'IN-PROGRESS' && incident != null) {
        final incidentType = incident['incidentType'] ?? 'Unknown';
        print('🔔 Triggering notification for incident status change to IN-PROGRESS');
        
        // Trigger local notification for immediate feedback
        try {
          _notificationService ??= NotificationService();
          await _notificationService!.handleIncidentStatusChange(
            incidentId, 
            status, 
            incidentType
          );
          print('🔔 Local notification triggered successfully');
        } catch (e) {
          print('🚨 Error triggering local notification: $e');
        }
        
        // Also attempt to send notification to backend for push notifications
        try {
          await _sendNotificationToBackend(incidentId, status, incidentType, incident);
        } catch (e) {
          print('🚨 Error sending notification to backend: $e');
        }
      }

      return success;
    } catch (e) {
      print('🚨 Error updating incident status: $e');
      return false;
    }
  }

  // Method to send notification request to backend
  Future<void> _sendNotificationToBackend(
    String incidentId, 
    String status, 
    String incidentType, 
    Map<String, dynamic> incident
  ) async {
    try {
      final location = incident['incidentLocation'];
      final description = incident['description'] ?? '';
      
      await _dio.post(
        '$baseUrl/api/notifications/send',
        data: jsonEncode({
          'incidentId': incidentId,
          'status': status,
          'incidentType': incidentType,
          'title': 'Incident Update: $incidentType',
          'body': 'An incident has been updated to $status status',
          'data': {
            'incidentId': incidentId,
            'status': status,
            'incidentType': incidentType,
            'location': location,
            'description': description.length > 100 
              ? '${description.substring(0, 100)}...' 
              : description,
          },
          'targetRoles': ['ADMINISTRATOR', 'MANAGER', 'OFFICER'],
        }),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (_authService.authToken != null)
              'Authorization': 'Bearer ${_authService.authToken}',
          },
        ),
      );
      
      print('🔔 Notification request sent to backend successfully');
    } catch (e) {
      print('🚨 Error sending notification to backend: $e');
      // Don't throw error, just log it as this is not critical for the main operation
    }
  }

  List<Map<String, dynamic>> _getMockIncidents() {
    final now = DateTime.now();
    return [
      {
        '_id': '68977108c8aaec3aecd89001',
        'userId': 'JRpizMSn5WSrpByg4',
        'incidentType': 'Fire',
        'description': 'Building fire at Main Street',
        'incidentLocation': {
          'latitude': '14.5995',
          'longitude': '120.9842',
        },
        'status': 'IN-PROGRESS',
        'createdAt': {
          '\$date': {
            '\$numberLong': now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch.toString()
          }
        },
        'updatedAt': {
          '\$date': {
            '\$numberLong': now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch.toString()
          }
        },
        'isActive': true,
        'priority': 'HIGH',
        'emergencyLevel': 'Critical',
        'files': [
          {
            'name': 'fire_incident.jpg',
            'type': 'image/jpeg',
            'size': 25000,
            'data': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=='
          }
        ],
      },
      {
        '_id': '68977108c8aaec3aecd89002',
        'userId': 'JRpizMSn5WSrpByg5',
        'incidentType': 'Medical Emergency',
        'description': 'Heart attack patient needs immediate assistance',
        'incidentLocation': {
          'latitude': '14.6042',
          'longitude': '120.9822',
        },
        'status': 'IN-PROGRESS',
        'createdAt': {
          '\$date': {
            '\$numberLong': now.subtract(const Duration(minutes: 45)).millisecondsSinceEpoch.toString()
          }
        },
        'updatedAt': {
          '\$date': {
            '\$numberLong': now.subtract(const Duration(minutes: 30)).millisecondsSinceEpoch.toString()
          }
        },
        'isActive': true,
        'priority': 'HIGH',
        'emergencyLevel': 'Critical',
        'files': [],
      },
      {
        '_id': '68977108c8aaec3aecd89003',
        'userId': 'JRpizMSn5WSrpByg6',
        'incidentType': 'Traffic Accident',
        'description': 'Car accident with multiple vehicles',
        'incidentLocation': {
          'latitude': '14.6000',
          'longitude': '120.9800',
        },
        'status': 'IN-PROGRESS',
        'createdAt': {
          '\$date': {
            '\$numberLong': now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch.toString()
          }
        },
        'updatedAt': {
          '\$date': {
            '\$numberLong': now.subtract(const Duration(minutes: 15)).millisecondsSinceEpoch.toString()
          }
        },
        'isActive': true,
        'priority': 'MEDIUM',
        'emergencyLevel': 'Moderate',
        'files': [
          {
            'name': 'accident1.jpg',
            'type': 'image/jpeg',
            'size': 30000,
            'data': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwABBgABWVUqfgAAAABJRU5ErkJggg=='
          },
          {
            'name': 'accident_video.mp4',
            'type': 'video/mp4',
            'size': 150000,
            'data': 'data_placeholder_for_video'
          }
        ],
      },
    ];
  }

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final currentUserId = await _authService.getUserId();
      
      final response = await _dio.get(
        '$baseUrl/api/admin/users/$userId',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (_authService.authToken != null)
              'Authorization': 'Bearer ${_authService.authToken}',
            if (currentUserId != null)
              'X-User-ID': currentUserId,
          },
        ),
      );

      if (response.statusCode == 200) {
        // Handle both parsed JSON and JSON string responses
        if (response.data is String) {
          return jsonDecode(response.data);
        } else {
          return response.data;
        }
      }
      
      return null;
    } catch (e) {
      print('🚨 Error fetching user details: $e');
      // Return mock user data based on the structure you provided
      return _getMockUserById(userId);
    }
  }

  Map<String, dynamic>? _getMockUserById(String userId) {
    // Mock user data based on your provided structure
    return {
      '_id': userId,
      'fullName': 'JUAN DELA CRUZ',
      'firstName': 'JUAN',
      'lastName': 'DELA CRUZ',
      'username': 'juan.delacruz',
      'phone': '+639171234570',
      'email': 'juandelacruz@gmail.com',
      'role': 'USER',
      'isActive': true,
    };
  }
}