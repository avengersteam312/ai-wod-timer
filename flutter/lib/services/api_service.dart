import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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
  ApiService._internal({
    Future<Map<String, dynamic>> Function(String input)? parseWorkoutOverride,
    Future<Map<String, dynamic>> Function(File imageFile)?
        parseWorkoutFromImageOverride,
  })  : _parseWorkoutOverride = parseWorkoutOverride,
        _parseWorkoutFromImageOverride = parseWorkoutFromImageOverride;
  ApiService.test({
    Future<Map<String, dynamic>> Function(String input)? parseWorkoutOverride,
    Future<Map<String, dynamic>> Function(File imageFile)?
        parseWorkoutFromImageOverride,
  }) : this._internal(
          parseWorkoutOverride: parseWorkoutOverride,
          parseWorkoutFromImageOverride: parseWorkoutFromImageOverride,
        );

  final String _baseUrl = AppConfig.apiBaseUrl;
  final Future<Map<String, dynamic>> Function(String input)?
      _parseWorkoutOverride;
  final Future<Map<String, dynamic>> Function(File imageFile)?
      _parseWorkoutFromImageOverride;

  Map<String, String> get _headers {
    return _headersWithToken(null);
  }

  /// Build headers, using [explicitAccessToken] when non-null so retry after refresh uses the new token.
  Map<String, String> _headersWithToken(String? explicitAccessToken) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = explicitAccessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      return headers;
    }
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

  // AI Workout Parsing (longer timeout to allow backend cold start, e.g. Render)
  Future<Map<String, dynamic>> parseWorkout(String input) async {
    if (_parseWorkoutOverride != null) {
      return _parseWorkoutOverride!(input);
    }

    try {
      return await _parseWorkoutOnce(input);
    }     on ApiException catch (e) {
      if (e.statusCode == 401) {
        try {
          final response = await Supabase.instance.client.auth.refreshSession();
          final newToken = response.session?.accessToken;
          if (newToken != null) {
            return await _parseWorkoutOnce(input, accessToken: newToken);
          }
        } catch (_) {}
        throw ApiException(e.message, statusCode: 401);
      }
      rethrow;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> _parseWorkoutOnce(String input,
      {String? accessToken}) async {
    final uri = Uri.parse('$_baseUrl/api/v1/timer/parse');
    final headers = _headersWithToken(accessToken);
    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({'workout_text': input}),
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw ApiException(
            'Request timed out (server may be starting up). Try again in a moment.',
            statusCode: 408,
          ),
        );
    return _handleResponse(response);
  }

  // AI Workout Parsing from Image (Vision API)
  Future<Map<String, dynamic>> parseWorkoutFromImage(File imageFile) async {
    if (_parseWorkoutFromImageOverride != null) {
      return _parseWorkoutFromImageOverride!(imageFile);
    }
    try {
      return await _parseWorkoutFromImageOnce(imageFile);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        try {
          final response = await Supabase.instance.client.auth.refreshSession();
          final newToken = response.session?.accessToken;
          return await _parseWorkoutFromImageOnce(imageFile,
              accessToken: newToken);
        } catch (_) {
          throw ApiException(e.message, statusCode: 401);
        }
      }
      rethrow;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> _parseWorkoutFromImageOnce(File imageFile,
      {String? accessToken}) async {
    final uri = Uri.parse('$_baseUrl/api/v1/timer/parse-image');
    final request = http.MultipartRequest('POST', uri);
    final headers = _headersWithToken(accessToken);
    request.headers['Accept'] = 'application/json';
    final auth = headers['Authorization'];
    if (auth != null) request.headers['Authorization'] = auth;
    final fileName = imageFile.path.split('/').last;
    final extension = fileName.split('.').last.toLowerCase();
    String mimeType;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        mimeType = 'image/jpeg';
        break;
      case 'png':
        mimeType = 'image/png';
        break;
      case 'webp':
        mimeType = 'image/webp';
        break;
      case 'gif':
        mimeType = 'image/gif';
        break;
      default:
        mimeType = 'image/jpeg';
    }
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      imageFile.path,
      contentType: MediaType.parse(mimeType),
    ));
    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
      onTimeout: () => throw ApiException(
        'Request timed out. The image may be too large or the server is busy.',
        statusCode: 408,
      ),
    );
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }
}
