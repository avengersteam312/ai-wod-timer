import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw AuthException(_mapAuthError(e.message));
    } catch (e) {
      throw AuthException('Failed to sign in. Please try again.');
    }
  }

  // Sign up with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'display_name': displayName} : null,
      );
      return response;
    } on AuthException catch (e) {
      throw AuthException(_mapAuthError(e.message));
    } catch (e) {
      throw AuthException('Failed to sign up. Please try again.');
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      final success = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'com.wodtimer.aiwodtimer://login-callback',
      );
      return success;
    } catch (e) {
      throw AuthException('Failed to sign in with Google. Please try again.');
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
        redirectTo: kIsWeb ? null : 'com.wodtimer.aiwodtimer://reset-callback',
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
