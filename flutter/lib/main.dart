import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_bootstrap.dart';
import 'services/audio_service.dart';
import 'services/offline_storage_service.dart';
import 'services/sync_service.dart';
import 'config/app_config.dart';
import 'observability/observability.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sentry wraps everything: Zone (async errors), FlutterError.onError (widget errors),
  // and PlatformDispatcher.onError (platform channel errors) are all covered by appRunner.
  await configureObservability(() async {
    await dotenv.load(fileName: '.env');

    await OfflineStorageService().init();

    // Connectivity + local cache; uses Supabase when configured
    await SyncService().init();

    // Initialize Supabase whenever both URL and anon key are configured so Sign In/Sign Up work.
    // authRequired only controls whether the app gates access; auth must be initialized if user can log in.
    if (AppConfig.hasSupabaseConfig) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          // Disable automatic deep link handling so we can catch password recovery
          // events even when app is cold-started. See: https://github.com/supabase/supabase-flutter/issues/937
          detectSessionInUri: false,
        ),
      );
    }

    await AudioService.instance.init();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0A0A0A),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    runConfiguredApp();
  });
}
