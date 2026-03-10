import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import '../services/auth_service.dart';
import '../models/user.dart';
import '../config/app_config.dart';

class AuthProvider with ChangeNotifier {
  AuthService? _authService;

  AppUser? _user;
  bool _isLoading = true;
  String? _error;
  String? _successMessage;
  bool _isInPasswordRecovery = false;
  StreamSubscription<AuthState>? _authSubscription;

  AuthProvider() {
    _init();
  }

  AuthService get authService {
    _authService ??= AuthService();
    return _authService!;
  }

  // Getters
  AppUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get successMessage => _successMessage;
  bool get isInPasswordRecovery => _isInPasswordRecovery;

  void _init() {
    // Skip auth initialization if not enabled or Supabase not configured
    if (!AppConfig.authEnabled || !AppConfig.hasSupabaseConfig) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Listen to auth state changes
    _authSubscription = authService.authStateChanges.listen(
      (state) {
        _handleAuthStateChange(state);
      },
      onError: (error) {
        debugPrint('Auth state error: $error');
        // Handle expired/invalid email links gracefully
        final errorStr = error.toString().toLowerCase();
        if (errorStr.contains('expired') || errorStr.contains('otp_expired') ||
            errorStr.contains('invalid')) {
          _error = 'Email link has expired. Please request a new one.';
        } else {
          _error = 'Authentication error. Please try again.';
        }
        _isLoading = false;
        _isInPasswordRecovery = false;
        notifyListeners();
      },
    );

    // Check current session
    _checkCurrentSession();
  }

  void _checkCurrentSession() {
    final session = authService.currentSession;
    if (session != null) {
      _setUserFromSession(session);
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _handleAuthStateChange(AuthState state) {
    switch (state.event) {
      case AuthChangeEvent.signedIn:
        if (state.session != null) {
          // Check if this is a new sign in (user was not authenticated before)
          final wasNotAuthenticated = _user == null;
          _setUserFromSession(state.session!);
          if (wasNotAuthenticated && !_isLoading) {
            // User just verified email or signed in via deep link
            _successMessage = 'Email verified! You are now signed in.';
            notifyListeners();
          }
        }
        break;
      case AuthChangeEvent.tokenRefreshed:
        if (state.session != null) {
          _setUserFromSession(state.session!);
        }
        break;
      case AuthChangeEvent.signedOut:
        _user = null;
        _isLoading = false;
        notifyListeners();
        break;
      case AuthChangeEvent.userUpdated:
        if (state.session != null) {
          _setUserFromSession(state.session!);
        }
        break;
      case AuthChangeEvent.passwordRecovery:
        debugPrint('Password recovery event received');
        _isInPasswordRecovery = true;
        if (state.session != null) {
          _setUserFromSession(state.session!);
        }
        notifyListeners();
        break;
      default:
        break;
    }
  }

  void _setUserFromSession(Session session) {
    final supabaseUser = session.user;
    _user = AppUser(
      id: supabaseUser.id,
      email: supabaseUser.email ?? '',
      displayName: supabaseUser.userMetadata?['display_name'] as String?,
      avatarUrl: supabaseUser.userMetadata?['avatar_url'] as String?,
      createdAt: DateTime.parse(supabaseUser.createdAt),
    );
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await authService.signInWithEmail(
        email: email,
        password: password,
      );

      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await authService.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );

      // If user needs to confirm email
      if (response.user != null && response.session == null) {
        _isLoading = false;
        notifyListeners();
        return true; // Signed up but needs email confirmation
      }

      return true;
    } on AuthException catch (e) {
      debugPrint('[AuthProvider] signUp AuthException: ${e.message}');
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e, stackTrace) {
      debugPrint('[AuthProvider] signUp error: $e');
      debugPrint('[AuthProvider] signUp stackTrace: $stackTrace');
      _error = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await authService.signInWithGoogle();

      if (!success) {
        _error = 'Google sign in was cancelled.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithApple() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await authService.signInWithApple();

      if (!success) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();

      await authService.signOut();

      _user = null;
      _error = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to sign out. Please try again.';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await authService.resetPassword(email);

      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    try {
      debugPrint('Updating password...');
      _isLoading = true;
      _error = null;
      notifyListeners();

      await authService.updatePassword(newPassword);

      debugPrint('Password updated successfully');
      _isInPasswordRecovery = false;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      debugPrint('Update password AuthException: ${e.message}');
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Update password error: $e');
      _error = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearPasswordRecovery() {
    _isInPasswordRecovery = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearSuccessMessage() {
    _successMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
