import 'package:dio/dio.dart';
import 'package:fireout/config/app_config.dart';
import 'package:fireout/services/auth_service.dart';

class StationService {
  static final StationService _instance = StationService._internal();
  factory StationService() => _instance;
  StationService._internal();

  final Dio _dio = Dio();
  final AuthService _authService = AuthService();

  String get baseUrl => AppConfig.instance.baseUrl;

  Future<List<Map<String, dynamic>>> getStations() async {
    try {
      print('🏢 Fetching stations from: $baseUrl/api/stations');
      
      final response = await _dio.get(
        '$baseUrl/api/stations',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (_authService.authToken != null)
              'Authorization': 'Bearer ${_authService.authToken}',
          },
        ),
      );

      print('✅ Stations response status: ${response.statusCode}');
      print('✅ Stations response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data is String ? 
          throw Exception('Unexpected string response') : response.data;
        
        List<Map<String, dynamic>> stations = [];
        
        if (data is List) {
          stations = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['response'] != null) {
          stations = List<Map<String, dynamic>>.from(data['response']);
        } else if (data is Map && data['stations'] != null) {
          stations = List<Map<String, dynamic>>.from(data['stations']);
        } else if (data is Map && data['status'] == 'Success' && data['response'] != null) {
          stations = List<Map<String, dynamic>>.from(data['response']);
        }
        
        // Process stations to add missing fields for compatibility
        final processedStations = stations.map((station) {
          // Infer type from name if not provided
          String inferredType = 'Emergency Station';
          final name = station['name']?.toString().toLowerCase() ?? '';

          if (name.contains('fire')) {
            inferredType = 'Fire Department';
          } else if (name.contains('police')) {
            inferredType = 'Police';
          } else if (name.contains('hospital') || name.contains('medical')) {
            inferredType = 'Medical Emergency';
          }

          return {
            ...station,
            'type': station['type'] ?? inferredType,
            'emergencyNumber': station['emergencyNumber'] ?? '911',
            'coverageRadius': _toDouble(station['coverageRadius']) ?? 7.0,
          };
        }).toList();
        
        print('🏢 Processed ${processedStations.length} stations successfully');
        for (int i = 0; i < processedStations.length; i++) {
          final station = processedStations[i];
          print('🏢 Station $i: ${station['name']} (${station['type']})');
        }
        
        return processedStations;
      }
      
      return [];
    } catch (e) {
      print('🚨 Error fetching stations: $e');
      if (e is DioException) {
        print('🚨 Dio error type: ${e.type}');
        print('🚨 Dio message: ${e.message}');
        print('🚨 Response data: ${e.response?.data}');
      }
      
      // Return empty array on error instead of mock stations to avoid duplicates
      return [];
    }
  }

  Future<Map<String, dynamic>?> getStationById(String id) async {
    final stations = await getStations();
    for (final station in stations) {
      if (station['_id']?.toString() == id) return station;
    }
    return null;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  List<Map<String, dynamic>> _getMockStations() {
    return [
      {
        '_id': 'station_1',
        'name': 'Fire Station Central',
        'type': 'Fire Department',
        'address': 'Roxas City, Capiz',
        'phone': '+63 36 621 0911',
        'emergencyNumber': '911',
        'latitude': 11.5877,
        'longitude': 122.7519,
        'services': ['Fire Response', 'Rescue Operations'],
        'isActive': true,
      },
      {
        '_id': 'station_2',
        'name': 'Roxas City Police Station',
        'type': 'Police',
        'address': 'Roxas City, Capiz',
        'phone': '+63 36 621 2345',
        'emergencyNumber': '911',
        'latitude': 11.5850,
        'longitude': 122.7500,
        'services': ['Law Enforcement', 'Emergency Response'],
        'isActive': true,
      },
      {
        '_id': 'station_3',
        'name': 'Capiz Emmanuel Hospital',
        'type': 'Medical Emergency',
        'address': 'Roxas City, Capiz',
        'phone': '+63 36 621 3456',
        'emergencyNumber': '911',
        'latitude': 11.5900,
        'longitude': 122.7600,
        'services': ['Emergency Care', 'Ambulance Services'],
        'isActive': true,
      },
    ];
  }
}