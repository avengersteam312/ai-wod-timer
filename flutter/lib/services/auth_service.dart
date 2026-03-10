import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // Auth state stream
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // Current session
  Session? get currentSession => _client.auth.currentSession;

  // Current user
  User? get currentUser => _client.auth.currentUser;

  // Check if authenticated
  bool get isAuthenticated => currentSession != null;

  // Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'signInWithEmail: attempting',
      category: 'auth',
      level: SentryLevel.info,
    ));
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'signInWithEmail: success',
        category: 'auth',
        level: SentryLevel.info,
      ));
      return response;
    } on AuthException catch (e) {
      debugPrint('[AuthService] SignIn AuthException: ${e.message}');
      throw AuthException(_mapAuthError(e.message));
    } catch (e, stackTrace) {
      debugPrint('[AuthService] SignIn error: $e');
      Sentry.captureException(e, stackTrace: stackTrace);
      throw AuthException('Failed to sign in. Please try again.');
    }
  }

  // Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'signUpWithEmail: attempting',
      category: 'auth',
      level: SentryLevel.info,
    ));
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'display_name': displayName} : null,
      );
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'signUpWithEmail: success',
        category: 'auth',
        level: SentryLevel.info,
      ));
      return response;
    } on AuthException catch (e) {
      debugPrint('[AuthService] SignUp AuthException: ${e.message}');
      throw AuthException(_mapAuthError(e.message));
    } catch (e, stackTrace) {
      debugPrint('[AuthService] SignUp error: $e');
      Sentry.captureException(e, stackTrace: stackTrace);
      throw AuthException('Failed to sign up. Please try again.');
    }
  }

  // Sign in with Google (Supabase OAuth)
  Future<bool> signInWithGoogle() async {
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'signInWithGoogle: attempting',
      category: 'auth',
      level: SentryLevel.info,
    ));
    try {
      // For web, use the default OAuth flow
      if (kIsWeb) {
        return await _client.auth.signInWithOAuth(OAuthProvider.google);
      }

      // For mobile, build OAuth URL and launch externally
      final redirectTo = AppConfig.loginCallbackUrl;

      // Get the OAuth URL from Supabase
      final res = await _client.auth.getOAuthSignInUrl(
        provider: OAuthProvider.google,
        redirectTo: redirectTo,
      );

      final url = Uri.parse(res.url);

      // Launch in external browser
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw AuthException('Could not open browser for sign in.');
      }

      // The app will receive the callback via deep link
      // Supabase SDK handles it automatically
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'signInWithGoogle: browser launched, awaiting callback',
        category: 'auth',
        level: SentryLevel.info,
      ));
      return true;
    } catch (e, stackTrace) {
      debugPrint('[AuthService] Google sign in error: $e');
      if (e is AuthException) rethrow;
      Sentry.captureException(e, stackTrace: stackTrace);
      throw AuthException('Failed to sign in with Google. Please try again.');
    }
  }

  // Sign in with Apple (native iOS sheet)
  Future<bool> signInWithApple() async {
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'signInWithApple: requesting credential',
      category: 'auth',
      level: SentryLevel.info,
    ));
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        Sentry.captureMessage(
          'Apple sign in: identityToken is null',
          level: SentryLevel.error,
        );
        throw AuthException('Apple sign in failed: no identity token.');
      }

      Sentry.addBreadcrumb(Breadcrumb(
        message: 'signInWithApple: got credential, calling signInWithIdToken',
        category: 'auth',
        level: SentryLevel.info,
      ));

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
      );

      Sentry.addBreadcrumb(Breadcrumb(
        message: 'signInWithApple: success',
        category: 'auth',
        level: SentryLevel.info,
      ));
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return false;
      }
      debugPrint('[AuthService] Apple sign in error: ${e.message}');
      Sentry.captureException(e);
      throw AuthException('Apple sign in failed. Please try again.');
    } catch (e, stackTrace) {
      debugPrint('[AuthService] Apple sign in error: $e');
      if (e is AuthException) rethrow;
      Sentry.captureException(e, stackTrace: stackTrace);
      throw AuthException('Failed to sign in with Apple. Please try again.');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw AuthException('Failed to sign out. Please try again.');
    }
  }

  // Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? null : AppConfig.resetCallbackUrl,
      );
    } on AuthException catch (e) {
      throw AuthException(_mapAuthError(e.message));
    } catch (e) {
      throw AuthException('Failed to send reset email. Please try again.');
    }
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw AuthException(_mapAuthError(e.message));
    } catch (e) {
      throw AuthException('Failed to update password. Please try again.');
    }
  }

  // Refresh session
  Future<void> refreshSession() async {
    try {
      await _client.auth.refreshSession();
    } catch (e) {
      debugPrint('Failed to refresh session: $e');
    }
  }

  // Map Supabase auth errors to user-friendly messages
  String _mapAuthError(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('invalid login credentials') ||
        lowerMessage.contains('invalid email or password')) {
      return 'Invalid email or password. Please try again.';
    }

    if (lowerMessage.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }

    if (lowerMessage.contains('user already registered') ||
        lowerMessage.contains('email already in use')) {
      return 'An account with this email already exists.';
    }

    if (lowerMessage.contains('password') &&
        lowerMessage.contains('characters')) {
      return 'Password must be at least 6 characters long.';
    }

    if (lowerMessage.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }

    if (lowerMessage.contains('rate limit') ||
        lowerMessage.contains('too many requests')) {
      return 'Too many attempts. Please wait and try again.';
    }

    if (lowerMessage.contains('network') ||
        lowerMessage.contains('connection')) {
      return 'Network error. Please check your connection.';
    }

    return message;
  }
}
