import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Configure Sentry and run the app inside Sentry's error zone.
///
/// Pass everything from after WidgetsFlutterBinding.ensureInitialized()
/// up to and including runApp() as [appRunner]. Sentry wraps it with:
///   - runZonedGuarded  → uncaught async Dart errors
///   - FlutterError.onError → widget build / rendering errors
///   - PlatformDispatcher.instance.onError → platform channel errors
///
/// When SENTRY_DSN is not injected (local dev), appRunner is called directly
/// with no Sentry overhead.
///
/// Inject at build time:
///   flutter run \
///     --dart-define=SENTRY_DSN=https://... \
///     --dart-define=ENV=production
Future<void> configureObservability(Future<void> Function() appRunner) async {
  const dsn = String.fromEnvironment('SENTRY_DSN');

  if (dsn.isEmpty) {
    // Local dev — run without Sentry, no overhead
    await appRunner();
    return;
  }

  await SentryFlutter.init(
    (options) => options
      ..dsn = dsn
      ..environment =
          const String.fromEnvironment('ENV', defaultValue: 'development')
      ..debug = kDebugMode
      // 10% trace sampling in prod — stays within the free tier
      ..tracesSampleRate = kDebugMode ? 1.0 : 0.1
      // Release health: track crash-free session rate
      ..autoSessionTrackingInterval = const Duration(minutes: 30)
      // Filter out expected auth errors (expired links are user errors, not bugs)
      ..beforeSend = (event, hint) {
        final message = event.throwable?.toString() ?? '';
        if (message.contains('otp_expired') ||
            message.contains('Email link is invalid')) {
          return null; // Drop event — don't send to Sentry
        }
        return event;
      },
    // appRunner gives Sentry full Zone coverage — all three error hooks fire
    appRunner: appRunner,
  );
}

// Capture errors manually at key boundaries:
//   import 'package:sentry_flutter/sentry_flutter.dart';
//   await Sentry.captureException(error, stackTrace: stackTrace);
//
// Key places to instrument:
//   - Parse API HTTP errors (workout_provider.dart)
//   - Timer FSM unexpected state transitions
//   - Offline sync failures
