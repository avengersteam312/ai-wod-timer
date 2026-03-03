import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Supabase Configuration
  static const String supabaseUrlPlaceholder = 'https://your-project.supabase.co';

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ?? supabaseUrlPlaceholder;

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// True when both Supabase URL and anon key are set to real values (not placeholders/empty).
  static bool get hasSupabaseConfig =>
      supabaseAnonKey.isNotEmpty && supabaseUrl != supabaseUrlPlaceholder;

  // Backend API Configuration
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';

  // Development Settings
  static bool get authRequired =>
      (dotenv.env['AUTH_REQUIRED'] ?? 'true').toLowerCase() == 'true';

  // App Configuration
  static const String appName = 'AI WOD Timer';
  static const String appVersion = '1.0.0';

  // Timer Defaults
  static const int defaultCountdownSeconds = 10;
  static const int defaultRestSeconds = 60;
  static const int defaultEmomIntervalSeconds = 60;
  static const int defaultTabataWorkSeconds = 20;
  static const int defaultTabataRestSeconds = 10;
  static const int defaultTabataRounds = 8;
}
