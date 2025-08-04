import 'package:dio/dio.dart';
import 'package:fireout/config/app_config.dart';
import 'package:fireout/services/auth_service.dart';
import 'dart:convert';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  
  String get baseUrl => AppConfig.instance.baseUrl;

  Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    try {
      print('🔍 Updating profile: $baseUrl/api/admin/user/update');
      print('🔍 Profile data: $profileData');
      
      // Get auth token if available
      final authService = AuthService();
      print('🔍 Auth token: ${authService.authToken}');
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      if (authService.authToken != null) {
        headers['Authorization'] = 'Bearer ${authService.authToken}';
      }
      
      // Add auth token to request body for Meteor.js compatibility
      final requestData = Map<String, dynamic>.from(profileData);
      if (authService.authToken != null) {
        requestData['authToken'] = authService.authToken;
      }
      
      final response = await _dio.post(
        '$baseUrl/api/admin/user/update',
        data: requestData,
        options: Options(headers: headers),
      );

      print('✅ Profile update response status: ${response.statusCode}');
      print('✅ Profile update response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data) 
            : response.data;
        
        return data['status'] == 'Success' || data['success'] == true || data['error'] == false;
      }
      
      return false;
    } catch (e) {
      print('🚨 Error updating profile: $e');
      if (e is DioException) {
        print('🚨 Dio error type: ${e.type}');
        print('🚨 Dio message: ${e.message}');
        print('🚨 Response data: ${e.response?.data}');
        print('🚨 Status code: ${e.response?.statusCode}');
        
        // Handle specific server errors
        if (e.response?.statusCode == 500) {
          final responseData = e.response?.data;
          if (responseData != null && responseData['message'] != null) {
            print('🚨 Server error: ${responseData['message']}');
            // If the error mentions null _id, it's likely a server-side issue
            if (responseData['message'].toString().contains('_id')) {
              print('🚨 Server cannot find user with provided ID');
            }
          }
        }
      }
      
      // Return false for actual errors to show proper error message
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableStations() async {
    try {
      print('🔍 Fetching available stations: $baseUrl/api/admin/station');
      
      final response = await _dio.get(
        '$baseUrl/api/admin/station',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      print('✅ Stations response status: ${response.statusCode}');
      print('✅ Stations response data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data) 
            : response.data;
        
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['response'] != null) {
          return List<Map<String, dynamic>>.from(data['response']);
        } else if (data is Map && data['stations'] != null) {
          return List<Map<String, dynamic>>.from(data['stations']);
        } else if (data is Map && data['error'] == false && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      
      return _getMockStationsData();
    } catch (e) {
      print('🚨 Error fetching stations: $e');
      if (e is DioException) {
        print('🚨 Dio error type: ${e.type}');
        print('🚨 Dio message: ${e.message}');
        print('🚨 Response data: ${e.response?.data}');
      }
      
      // Return mock data for now
      return _getMockStationsData();
    }
  }

  Future<Map<String, dynamic>?> getStationById(String stationId) async {
    try {
      // First try to get from the available stations list
      final stations = await getAvailableStations();
      final station = stations.firstWhere(
        (s) => s['_id'] == stationId,
        orElse: () => {},
      );
      
      if (station.isNotEmpty) {
        return station;
      }
      
      return null;
    } catch (e) {
      print('🚨 Error fetching station by ID: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStationDetails(String stationId) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/admin/station/$stationId',
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
      print('🚨 Error fetching station details: $e');
      return null;
    }
  }

  List<Map<String, dynamic>> _getMockStationsData() {
    return [
      {
        '_id': 'NMSotJSHmteyrGCzJ',
        'name': 'Roxas City Fire Department',
        'address': 'Bilbao Street, Roxas City, Capiz, Philippines',
        'phone': '09171234567',
        'latitude': '11.585015587305465',
        'longitude': '122.75519281625748',
        'isActive': true,
      },
      {
        '_id': 'ABC123DEF456GHI',
        'name': 'Capiz Provincial Fire Station',
        'address': 'Capitol Road, Roxas City, Capiz, Philippines',
        'phone': '09181234568',
        'latitude': '11.590000000000000',
        'longitude': '122.760000000000000',
        'isActive': true,
      },
      {
        '_id': 'XYZ789UVW012STU',
        'name': 'Panay Fire District Office',
        'address': 'Main Street, Pontevedra, Capiz, Philippines',
        'phone': '09191234569',
        'latitude': '11.600000000000000',
        'longitude': '122.770000000000000',
        'isActive': true,
      },
    ];
  }
}