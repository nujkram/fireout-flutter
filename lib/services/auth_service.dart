import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:fireout/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  String get baseUrl => AppConfig.instance.baseUrl;

  void setupCookieManager() {
    if (!kIsWeb) {
      _dio.interceptors.add(CookieManager(CookieJar()));
    }
  }
  
  String? _authToken;
  String? get authToken => _authToken;
  
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataStr = prefs.getString('user_data');
    if (userDataStr != null) {
      final userData = jsonDecode(userDataStr);
      return userData['_id'] ?? userData['id'];
    }
    return null;
  }

  Future<String?> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataStr = prefs.getString('user_data');
    if (userDataStr != null) {
      final userData = jsonDecode(userDataStr);
      return userData['phone'];
    }
    return null;
  }

  Future<void> initializeAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    if (_authToken != null) {
      _dio.options.headers['Authorization'] = 'Bearer $_authToken';
    }
  }

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      // Hash password with SHA256 to match Svelte backend
      final hashedPassword = _hashPassword(password);
      
      print('🔍 Login attempt - URL: $baseUrl/api/auth/login');
      print('🔍 Username: $username');
      print('🔍 Password hash: $hashedPassword');
      
      final response = await _dio.post(
        '$baseUrl/api/auth/login',
        data: {
          'username': username,
          'password': hashedPassword,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );
      
      print('✅ Response status: ${response.statusCode}');
      print('✅ Response data: ${response.data}');
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data) 
            : response.data;
        
        // Check if login was successful (no error field)
        if (data['error'] == false) {
          // Store user data for session management
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_data', jsonEncode(data['user']));
          await prefs.setString('user_role', data['user']['role'] ?? 'USER');
          
          // Store the actual JWT token if provided by server
          if (data['token'] != null) {
            _authToken = data['token'];
            await prefs.setString('auth_token', _authToken!);
            _dio.options.headers['Authorization'] = 'Bearer $_authToken';
            print('✅ JWT token stored: ${_authToken?.substring(0, 20)}...');
          } else if (data['user']?['services']?['resume']?['loginTokens'] != null && 
                     (data['user']['services']['resume']['loginTokens'] as List).isNotEmpty) {
            // Use Meteor.js login token system
            final loginTokens = data['user']['services']['resume']['loginTokens'] as List;
            final latestToken = loginTokens.last;
            _authToken = latestToken['hashedToken'];
            await prefs.setString('auth_token', _authToken!);
            _dio.options.headers['Authorization'] = 'Bearer $_authToken';
            print('✅ Meteor login token stored: ${_authToken?.substring(0, 20)}...');
          } else {
            // Fallback: use simple flag for authentication state
            _authToken = 'logged_in';
            await prefs.setString('auth_token', _authToken!);
            print('⚠️ No JWT token in response, using simple auth flag');
          }
          
          return data; // Return user data
        } else {
          print('❌ Login failed - error in response');
          return null; // Login failed
        }
      }
      print('❌ Unexpected status code: ${response.statusCode}');
      return null;
    } catch (e) {
      print('🚨 Exception during login: $e');
      if (e is DioException) {
        print('🚨 Dio error type: ${e.type}');
        print('🚨 Dio message: ${e.message}');
        print('🚨 Response data: ${e.response?.data}');
        print('🚨 Status code: ${e.response?.statusCode}');
      }
      return null;
    }
  }

  Future<String?> getErrorMessage(String username, String password) async {
    try {
      final hashedPassword = _hashPassword(password);
      
      final response = await _dio.post(
        '$baseUrl/api/auth/login',
        data: {
          'username': username,
          'password': hashedPassword,
        },
      );
      
      if (response.statusCode == 200) {
        final data = response.data is String 
            ? jsonDecode(response.data) 
            : response.data;
        if (data['error'] == true) {
          return data['errorMessage'] ?? 'Login failed';
        }
      }
      return null;
    } catch (e) {
      if (e is DioException) {
        final responseData = e.response?.data;
        if (responseData != null && responseData['errorMessage'] != null) {
          return responseData['errorMessage'];
        }
        return 'Network error';
      }
      return 'An error occurred';
    }
  }

  Future<void> logout() async {
    _authToken = null;
    _dio.options.headers.remove('Authorization');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    await prefs.remove('user_role');
  }

  bool get isAuthenticated => _authToken != null;

  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString != null) {
        return jsonDecode(userDataString);
      }
      return null;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  Future<void> updateStoredUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_data', jsonEncode(userData));
      print('✅ User data updated in storage');
    } catch (e) {
      print('❌ Error updating stored user data: $e');
    }
  }

  Future<String?> getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_role');
    } catch (e) {
      print('❌ Error getting user role: $e');
      return null;
    }
  }

  Future<bool> hasRole(String role) async {
    final userRole = await getUserRole();
    return userRole == role;
  }

  Future<String> getAppropriateHomeRoute() async {
    final role = await getUserRole();
    switch (role) {
      case 'ADMINISTRATOR':
      case 'MANAGER':
      case 'OFFICER':
        return '/dashboard';
      case 'USER':
      default:
        return '/user-dashboard';
    }
  }
}