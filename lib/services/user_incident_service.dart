import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:fireout/config/app_config.dart';
import 'package:fireout/services/auth_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

class UserIncidentService {
  static final UserIncidentService _instance = UserIncidentService._internal();
  factory UserIncidentService() => _instance;
  UserIncidentService._internal() {
    _setupDio();
  }

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));
  // Separate Dio for uploads to external storage (S3/GCS) without cookies/authorization
  final Dio _externalDio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
  ));
  
  final AuthService _authService = AuthService();
  String get baseUrl => AppConfig.instance.baseUrl;

  void _setupDio() {
    if (!kIsWeb) {
      _dio.interceptors.add(CookieManager(CookieJar()));
    }
  }

  Future<Map<String, dynamic>?> submitIncident({
    required String incidentType,
    required double latitude,
    required double longitude,
    List<XFile>? mediaFiles,
    String? description,
  }) async {
    try {
      print('🔍 Submitting incident (JSON) to: $baseUrl/api/user/incident');

      // Get the userId and phone for this incident
      final userId = await _authService.getUserId();
      final userPhone = await _authService.getUserPhone();
      print('🔍 User ID for incident submission: $userId');
      print('🔍 User Phone for incident submission: $userPhone');
      
      if (userId == null) {
        throw IncidentSubmissionException('User not authenticated - cannot submit incident');
      }

      // Prepare media metadata via presigned upload or base64 inline (small files)
      List<Map<String, dynamic>> mediaMetadata = [];
      if (mediaFiles != null && mediaFiles.isNotEmpty) {
        mediaMetadata = await _prepareMediaMetadata(mediaFiles);
      }

      final payload = {
        'userId': userId,
        'incidentType': incidentType,
        'latitude': latitude,
        'longitude': longitude,
        if (userPhone != null && userPhone.isNotEmpty)
          'userPhone': userPhone,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (mediaMetadata.isNotEmpty) 'files': mediaMetadata,
      };

      final response = await _dio.post(
        '$baseUrl/api/user/incident',
        data: jsonEncode(payload),
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            if (_authService.authToken != null)
              'Authorization': 'Bearer ${_authService.authToken}',
            'X-User-ID': userId,
          },
        ),
      );

      print('✅ Submit response status: ${response.statusCode}');
      print('✅ Submit response data: ${response.data}');

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
      print('🚨 Error submitting incident: $e');
      if (e is DioException) {
        print('🚨 Dio error type: ${e.type}');
        print('🚨 Dio message: ${e.message}');
        print('🚨 Response data: ${e.response?.data}');
      }
      throw IncidentSubmissionException('Failed to submit incident: $e');
    }
  }

  // ----- Uploads & Media helpers -----

  // Max size for inline base64 (bytes). Base64 encoding increases size by ~33%
  static const int _inlineBase64MaxBytes = 500 * 1024; // 500 KB

  Future<List<Map<String, dynamic>>> _prepareMediaMetadata(List<XFile> mediaFiles) async {
    print('📁 Preparing ${mediaFiles.length} media file(s)');
    final List<Map<String, dynamic>> result = [];

    for (int i = 0; i < mediaFiles.length; i++) {
      final xfile = mediaFiles[i];
      final fileName = _inferFileName(xfile, i);
      final bytes = await xfile.readAsBytes();
      final size = bytes.length;
      final contentType = _inferContentType(fileName);

      // For now, use base64 inline upload only since presigned upload endpoint doesn't exist
      // TODO: Implement presigned upload when backend endpoint is available
      
      if (size <= _inlineBase64MaxBytes) {
        final base64Data = base64Encode(bytes);
        result.add({
          'name': fileName,
          'type': contentType,
          'size': size,
          'data': base64Data,
        });
        print('📎 Using base64 inline upload for $fileName (${(size / 1024).toStringAsFixed(1)} KB)');
      } else {
        throw IncidentSubmissionException(
          'File ${fileName} is too large (${(size / 1024).toStringAsFixed(0)} KB). Maximum size for inline upload is ${(_inlineBase64MaxBytes / 1024).toStringAsFixed(0)} KB.',
        );
      }
    }

    return result;
  }

  // TODO: Remove or implement when backend supports presigned uploads
  Future<Map<String, dynamic>?> _requestPresignedUrl(
    String fileName,
    String contentType,
    int size,
  ) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/uploads/presign',
        data: jsonEncode({
          'fileName': fileName,
          'contentType': contentType,
          'size': size,
          'purpose': 'incident-media',
        }),
        options: Options(headers: {
          'Content-Type': 'application/json',
          if (_authService.authToken != null)
            'Authorization': 'Bearer ${_authService.authToken}',
        }),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = Map<String, dynamic>.from(response.data);
        return data;
      }
      return null;
    } catch (e) {
      if (e is DioException) {
        print('🚨 Presign error: ${e.message} | ${e.response?.data}');
      } else {
        print('🚨 Presign error: $e');
      }
      return null;
    }
  }

  // TODO: Remove or implement when backend supports presigned uploads
  Future<void> _uploadToStorage(
    String uploadUrl,
    List<int> bytes,
    String contentType,
    Map<String, dynamic>? extraHeaders,
  ) async {
    final headers = <String, dynamic>{'Content-Type': contentType, ...?extraHeaders};
    await _externalDio.put(
      uploadUrl,
      data: bytes,
      options: Options(headers: headers, followRedirects: true),
    );
  }

  String _inferFileName(XFile xfile, int index) {
    if (xfile.name.isNotEmpty) return xfile.name;
    final pathPart = xfile.path.split('/').last;
    if (pathPart.isNotEmpty) return pathPart;
    return 'incident_media_$index';
  }

  String _inferContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    // Default binary stream
    return 'application/octet-stream';
  }

  Future<List<Map<String, dynamic>>> getUserIncidents() async {
    try {
      print('🔍 Fetching user incidents from: $baseUrl/api/user/incident');
      
      final userId = await _authService.getUserId();
      print('🔍 User ID from stored data: $userId');
      
      final response = await _dio.get(
        '$baseUrl/api/user/incident',
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

      print('✅ User incidents response status: ${response.statusCode}');
      print('✅ User incidents response data: ${response.data}');

      if (response.statusCode == 200) {
        // Handle both parsed JSON and JSON string responses
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        
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
      print('🚨 Error fetching user incidents: $e');
      if (e is DioException) {
        print('🚨 Dio error type: ${e.type}');
        print('🚨 Dio message: ${e.message}');
        print('🚨 Response data: ${e.response?.data}');
      }
      
      return _getMockUserIncidents();
    }
  }

  Future<Map<String, dynamic>?> getIncidentById(String incidentId) async {
    try {
      final userId = await _authService.getUserId();
      
      final response = await _dio.get(
        '$baseUrl/api/user/incident/$incidentId',
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
        // Handle both parsed JSON and JSON string responses
        if (response.data is String) {
          return jsonDecode(response.data);
        } else {
          return response.data;
        }
      }
      
      return null;
    } catch (e) {
      print('🚨 Error fetching incident details: $e');
      return null;
    }
  }

  List<Map<String, dynamic>> _getMockUserIncidents() {
    return [
      {
        '_id': 'user_1',
        'incidentType': 'Fire',
        'description': 'Small kitchen fire reported',
        'latitude': 14.5995,
        'longitude': 120.9842,
        'status': 'PENDING',
        'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'updatedAt': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        'media': [
          {'type': 'image', 'filename': 'kitchen_fire.jpg'},
        ],
      },
      {
        '_id': 'user_2',
        'incidentType': 'Medical Emergency',
        'description': 'Person collapsed on the street',
        'latitude': 14.6042,
        'longitude': 120.9822,
        'status': 'IN_PROGRESS',
        'createdAt': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
        'updatedAt': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
        'media': [],
      },
      {
        '_id': 'user_3',
        'incidentType': 'Traffic Accident',
        'description': 'Car accident at intersection',
        'latitude': 14.6000,
        'longitude': 120.9800,
        'status': 'RESOLVED',
        'createdAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'updatedAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'media': [
          {'type': 'image', 'filename': 'accident1.jpg'},
          {'type': 'image', 'filename': 'accident2.jpg'},
        ],
      },
    ];
  }
}

class IncidentSubmissionException implements Exception {
  final String message;
  IncidentSubmissionException(this.message);
  
  @override
  String toString() => message;
}