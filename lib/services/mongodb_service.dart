import 'package:dio/dio.dart';
import 'package:fireout/config/app_config.dart';
import 'auth_service.dart';

class MongoDBService {
  static final MongoDBService _instance = MongoDBService._internal();
  factory MongoDBService() => _instance;
  MongoDBService._internal();

  final Dio _dio = Dio();
  String get baseUrl => AppConfig.instance.baseUrl;

  Future<Map<String, dynamic>?> createDocument(String collection, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        '$baseUrl/$collection',
        data: data,
        options: Options(
          headers: {'Authorization': 'Bearer ${AuthService().authToken}'},
        ),
      );
      return response.data;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getDocuments(String collection, {Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get(
        '$baseUrl/$collection',
        queryParameters: query,
        options: Options(
          headers: {'Authorization': 'Bearer ${AuthService().authToken}'},
        ),
      );
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getDocument(String collection, String id) async {
    try {
      final response = await _dio.get(
        '$baseUrl/$collection/$id',
        options: Options(
          headers: {'Authorization': 'Bearer ${AuthService().authToken}'},
        ),
      );
      return response.data;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateDocument(String collection, String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(
        '$baseUrl/$collection/$id',
        data: data,
        options: Options(
          headers: {'Authorization': 'Bearer ${AuthService().authToken}'},
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteDocument(String collection, String id) async {
    try {
      final response = await _dio.delete(
        '$baseUrl/$collection/$id',
        options: Options(
          headers: {'Authorization': 'Bearer ${AuthService().authToken}'},
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}