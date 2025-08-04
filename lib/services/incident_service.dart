import 'package:dio/dio.dart';
import 'package:fireout/config/app_config.dart';
import 'dart:convert';

class IncidentService {
  static final IncidentService _instance = IncidentService._internal();
  factory IncidentService() => _instance;
  IncidentService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  
  String get baseUrl => AppConfig.instance.baseUrl;

  Future<List<Map<String, dynamic>>> getInProgressIncidents() async {
    try {
      print('🔍 Fetching in-progress incidents from: $baseUrl/api/admin/incident/in-progress');
      
      final response = await _dio.get(
        '$baseUrl/api/admin/incident/in-progress',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
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
      final response = await _dio.get(
        '$baseUrl/api/incidents/$incidentId',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
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
      final response = await _dio.put(
        '$baseUrl/api/incidents/$incidentId/status',
        data: {
          'status': status,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('🚨 Error updating incident status: $e');
      return false;
    }
  }

  List<Map<String, dynamic>> _getMockIncidents() {
    return [
      {
        '_id': '1',
        'type': 'Fire',
        'description': 'Building fire at Main Street',
        'location': 'Main Street, Building 45',
        'priority': 'HIGH',
        'status': 'IN_PROGRESS',
        'reportedBy': 'John Doe',
        'reportedAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'assignedTo': ['Officer Pedro'],
        'emergencyLevel': 'Critical',
      },
      {
        '_id': '2',
        'type': 'Medical Emergency',
        'description': 'Heart attack patient needs immediate assistance',
        'location': 'Oak Avenue, House 12',
        'priority': 'HIGH',
        'status': 'IN_PROGRESS',
        'reportedBy': 'Jane Smith',
        'reportedAt': DateTime.now().subtract(const Duration(minutes: 45)).toIso8601String(),
        'assignedTo': ['Officer Pedro'],
        'emergencyLevel': 'Critical',
      },
      {
        '_id': '3',
        'type': 'Accident',
        'description': 'Car accident with multiple vehicles',
        'location': 'Highway 101, Mile 23',
        'priority': 'MEDIUM',
        'status': 'IN_PROGRESS',
        'reportedBy': 'Traffic Control',
        'reportedAt': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        'assignedTo': ['Officer Pedro', 'Officer Maria'],
        'emergencyLevel': 'Moderate',
      },
    ];
  }
}