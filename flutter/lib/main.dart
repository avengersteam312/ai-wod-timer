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
import 'screens/auth/update_password_screen.dart';
import 'services/audio_service.dart';
import 'services/offline_storage_service.dart';
import 'services/sync_service.dart';
import 'config/app_config.dart';
import 'observability/observability.dart';
import 'utils/snackbar_utils.dart';

/// Global key for the root ScaffoldMessenger to show snackbars above bottom navigation
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Global navigator key for popping to root on deep link auth events
final rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
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

    runApp(const MyApp());
  });
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
        navigatorKey: rootNavigatorKey,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    // Auth is optional - always show AppShell
    // Users can sign in via AuthButton if they want
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // Show error when auth error occurs (e.g., expired email link)
        // Skip if in password recovery - let UpdatePasswordScreen handle errors
        if (auth.error != null && !auth.isInPasswordRecovery) {
          final errorMessage = auth.error!;
          auth.clearError();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              AppSnackBar.showError(context, errorMessage);
            }
          });
        }

        // Show email verified message
        if (auth.emailJustVerified) {
          auth.clearEmailVerified();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              AppSnackBar.showSuccess(context, 'Email verified!');
            }
          });
        }

        // Show password updated message
        if (auth.passwordJustUpdated) {
          auth.clearPasswordUpdated();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              AppSnackBar.showSuccess(context, 'Password updated!');
            }
          });
        }

        // Show success message if any (generic handler for future use)
        if (auth.successMessage != null) {
          final successMessage = auth.successMessage!;
          auth.clearSuccessMessage();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              AppSnackBar.showSuccess(context, successMessage);
            }
          });
        }

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

        // Show password update screen when user clicked reset link from email
        if (auth.isInPasswordRecovery) {
          // Pop any screens on top (e.g., login screen) to show recovery form
          WidgetsBinding.instance.addPostFrameCallback((_) {
            rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
          });
          return const UpdatePasswordScreen();
        }

        return const AppShell();
      },
    );
  }
}
