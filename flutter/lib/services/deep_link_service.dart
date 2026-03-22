import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to manually handle deep links for Supabase auth.
///
/// This is needed because when the app is cold-started via a deep link,
/// the AuthChangeEvent fires before listeners are subscribed.
/// See: https://github.com/supabase/supabase-flutter/issues/937
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  bool _initialized = false;

  /// Initialize deep link handling. Call this after Supabase.initialize()
  /// and after auth listeners are set up.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Handle deep link that launched the app (cold start)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('[DeepLinkService] Initial URI: $initialUri');
        await _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('[DeepLinkService] Error getting initial link: $e');
    }

    // Handle deep links while app is running (warm start)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) async {
        debugPrint('[DeepLinkService] Received URI: $uri');
        await _handleDeepLink(uri);
      },
      onError: (e) {
        debugPrint('[DeepLinkService] URI stream error: $e');
      },
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    // Check if this is an auth callback URL
    final isAuthCallback = uri.scheme.contains('aiwodtimer') ||
        uri.host.contains('callback') ||
        uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('error');

    if (!isAuthCallback) {
      debugPrint('[DeepLinkService] Not an auth callback, ignoring');
      return;
    }

    debugPrint('[DeepLinkService] Processing auth callback');

    try {
      // Let Supabase process the deep link and exchange code for session
      final response = await Supabase.instance.client.auth.getSessionFromUrl(uri);
      debugPrint('[DeepLinkService] Session obtained: ${response.session.user.email}');
    } on AuthException catch (e) {
      debugPrint('[DeepLinkService] Auth error: ${e.message}');
      // The error will be picked up by the auth state listener
    } catch (e) {
      debugPrint('[DeepLinkService] Error processing deep link: $e');
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _initialized = false;
  }
}
