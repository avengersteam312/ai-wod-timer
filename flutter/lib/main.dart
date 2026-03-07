import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/workout_provider.dart';
import 'providers/video_provider.dart';
import 'screens/app_shell.dart';
import 'services/audio_service.dart';
import 'services/offline_storage_service.dart';
import 'services/sync_service.dart';
import 'config/app_config.dart';

/// Global key for the root ScaffoldMessenger to show snackbars above bottom navigation
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Hive for local storage
  await OfflineStorageService().init();

  // Initialize sync service (connectivity + local cache); uses Supabase when configured
  await SyncService().init();

  // Initialize Supabase whenever both URL and anon key are configured so Sign In/Sign Up work.
  // authRequired only controls whether the app gates access; auth must be initialized if user can log in.
  if (AppConfig.hasSupabaseConfig) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  // Initialize audio service
  await AudioService.instance.init();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, WorkoutProvider>(
          create: (_) => WorkoutProvider(),
          update: (_, auth, workout) => workout!..updateAuth(auth),
        ),
        ChangeNotifierProvider(create: (_) => VideoProvider()),
      ],
      child: MaterialApp(
        title: 'AI WOD Timer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Auth is optional - always show AppShell
    // Users can sign in via AuthButton if they want
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Show loading only briefly while checking existing session
        if (auth.isLoading && AppConfig.authEnabled) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0A),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF8B5CF6),
              ),
            ),
          );
        }

        return const AppShell();
      },
    );
  }
}
