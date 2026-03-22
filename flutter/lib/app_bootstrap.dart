import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/video_provider.dart';
import 'providers/workout_provider.dart';
import 'screens/app_shell.dart';
import 'screens/auth/update_password_screen.dart';
import 'services/deep_link_service.dart';
import 'services/sync_service.dart';
import 'theme/app_theme.dart';
import 'utils/snackbar_utils.dart';

/// Global key for the root ScaffoldMessenger to show snackbars above bottom navigation.
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Global navigator key for popping to root on deep link auth events.
final rootNavigatorKey = GlobalKey<NavigatorState>();

typedef VideoPreviewBuilder = Widget Function(String videoPath);

class AppShellDependencies {
  final SyncService? syncService;
  final ImagePicker? imagePicker;
  final VideoPreviewBuilder? videoPreviewBuilder;

  const AppShellDependencies({
    this.syncService,
    this.imagePicker,
    this.videoPreviewBuilder,
  });
}

class AppBootstrap {
  final AuthProvider Function() createAuthProvider;
  final WorkoutProvider Function() createWorkoutProvider;
  final VideoProvider Function() createVideoProvider;
  final AppShellDependencies shellDependencies;

  AppBootstrap({
    AuthProvider Function()? createAuthProvider,
    WorkoutProvider Function()? createWorkoutProvider,
    VideoProvider Function()? createVideoProvider,
    AppShellDependencies? shellDependencies,
  })  : createAuthProvider = createAuthProvider ?? AuthProvider.new,
        createWorkoutProvider = createWorkoutProvider ?? WorkoutProvider.new,
        createVideoProvider = createVideoProvider ?? VideoProvider.new,
        shellDependencies = shellDependencies ?? const AppShellDependencies();
}

void runConfiguredApp({AppBootstrap? bootstrap}) {
  runApp(MyApp(bootstrap: bootstrap));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    AppBootstrap? bootstrap,
  }) : _bootstrap = bootstrap;

  final AppBootstrap? _bootstrap;

  @override
  Widget build(BuildContext context) {
    final bootstrap = _bootstrap ?? AppBootstrap();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => bootstrap.createAuthProvider(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, WorkoutProvider>(
          create: (_) => bootstrap.createWorkoutProvider(),
          update: (_, auth, workout) {
            final nextWorkout = workout ?? bootstrap.createWorkoutProvider();
            nextWorkout.updateAuth(auth);
            return nextWorkout;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => bootstrap.createVideoProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'AI WOD Timer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        navigatorKey: rootNavigatorKey,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: AuthWrapper(shellDependencies: bootstrap.shellDependencies),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({
    super.key,
    this.shellDependencies = const AppShellDependencies(),
  });

  final AppShellDependencies shellDependencies;

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Initialize deep link handling after auth listeners are set up.
    // This ensures password recovery deep links work even on cold start.
    DeepLinkService().init();
  }

  @override
  Widget build(BuildContext context) {
    // Auth is optional - always show AppShell.
    // Users can sign in via AuthButton if they want.
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.error != null && !auth.isInPasswordRecovery) {
          final errorMessage = auth.error!;
          auth.clearError();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              AppSnackBar.showError(context, errorMessage);
            }
          });
        }

        if (auth.emailJustVerified) {
          auth.clearEmailVerified();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              AppSnackBar.showSuccess(context, 'Email verified!');
            }
          });
        }

        if (auth.passwordJustUpdated) {
          auth.clearPasswordUpdated();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              AppSnackBar.showSuccess(context, 'Password updated!');
            }
          });
        }

        if (auth.successMessage != null) {
          final successMessage = auth.successMessage!;
          auth.clearSuccessMessage();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              AppSnackBar.showSuccess(context, successMessage);
            }
          });
        }

        if (auth.isLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0A),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF8B5CF6),
              ),
            ),
          );
        }

        if (auth.isInPasswordRecovery) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
          });
          return const UpdatePasswordScreen();
        }

        return AppShell(shellDependencies: widget.shellDependencies);
      },
    );
  }
}
