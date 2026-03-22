import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Report categories
enum ReportKind {
  wrongWorkoutType('wrong_workout_type', 'Wrong workout type'),
  wrongIntervals('wrong_intervals', 'Wrong intervals'),
  other('other', 'Other issue');

  final String value;
  final String displayLabel;
  const ReportKind(this.value, this.displayLabel);
}

class ReportException implements Exception {
  final String message;

  ReportException(this.message);

  @override
  String toString() => message;
}

class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  /// Submit a timer parsing problem report via backend API.
  /// Returns the report ID on success.
  Future<String> submitReport({
    required ReportKind kind,
    String? message,
    required Map<String, dynamic> originalParsed,
    Map<String, dynamic>? editedConfig,
    required String appVersion,
  }) async {
    // Determine platform
    String platform;
    if (kIsWeb) {
      platform = 'web';
    } else if (Platform.isIOS) {
      platform = 'ios';
    } else if (Platform.isAndroid) {
      platform = 'android';
    } else {
      platform = 'web'; // fallback
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/reports');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'report_kind': kind.value,
              'message': message,
              'original_parsed': originalParsed,
              'edited_config': editedConfig,
              'app_version': appVersion,
              'platform': platform,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return body['id'] as String;
      }

      if (response.statusCode == 429) {
        throw ReportException('Too many reports. Please try again later.');
      }

      String errorMessage;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        errorMessage = body['detail'] as String? ?? 'Failed to submit report';
      } catch (_) {
        errorMessage = 'Failed to submit report';
      }

      throw ReportException(errorMessage);
    } catch (e) {
      if (e is ReportException) rethrow;
      debugPrint('[ReportService] Error: $e');
      throw ReportException('Network error. Please check your connection.');
    }
  }
}
