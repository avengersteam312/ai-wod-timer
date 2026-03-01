import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String _baseUrl = AppConfig.apiBaseUrl;

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Add auth token if available
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        headers['Authorization'] = 'Bearer ${session.accessToken}';
      }
    } catch (_) {
      // Supabase not initialized, skip auth header
    }

    return headers;
  }

  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    try {
      var uri = Uri.parse('$_baseUrl$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http.get(uri, headers: _headers);
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final response = await http.post(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final response = await http.put(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final response = await http.patch(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final response = await http.delete(uri, headers: _headers);
      return _handleResponse(response);
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {'success': true};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    String message;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      message = body['detail'] as String? ??
          body['message'] as String? ??
          'Request failed';
    } catch (_) {
      message = 'Request failed with status ${response.statusCode}';
    }

    throw ApiException(message, statusCode: response.statusCode);
  }

  // AI Workout Parsing
  Future<Map<String, dynamic>> parseWorkout(String input) async {
    return await post('/api/v1/timer/parse', body: {'workout_text': input});
  }
}
