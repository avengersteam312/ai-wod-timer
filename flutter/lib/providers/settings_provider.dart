import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// User-specific settings provider
/// Settings are stored per user ID in Hive
class SettingsProvider with ChangeNotifier {
  static const String _boxName = 'user_settings';

  Box? _box;
  String? _userId;

  // Settings with defaults
  bool _videoOverlayEnabled = true;

  // Getters
  bool get videoOverlayEnabled => _videoOverlayEnabled;
  bool get isInitialized => _box != null;

  /// Initialize settings for a specific user
  Future<void> init(String? userId) async {
    _userId = userId;

    try {
      _box = await Hive.openBox(_boxName);
      _loadSettings();
    } catch (e) {
      debugPrint('[SettingsProvider] Failed to open settings box: $e');
    }
  }

  /// Load settings from Hive
  void _loadSettings() {
    if (_box == null || _userId == null) return;

    final key = _settingsKey;
    final settings = _box!.get(key, defaultValue: <String, dynamic>{});

    if (settings is Map) {
      _videoOverlayEnabled = settings['videoOverlayEnabled'] ?? true;
    }

    notifyListeners();
  }

  /// Save settings to Hive
  Future<void> _saveSettings() async {
    if (_box == null || _userId == null) return;

    final key = _settingsKey;
    await _box!.put(key, {
      'videoOverlayEnabled': _videoOverlayEnabled,
    });
  }

  /// Get settings key for current user
  String get _settingsKey => 'settings_$_userId';

  /// Toggle video overlay setting
  Future<void> setVideoOverlayEnabled(bool enabled) async {
    _videoOverlayEnabled = enabled;
    notifyListeners();
    await _saveSettings();
  }

  /// Reset settings to defaults
  Future<void> resetToDefaults() async {
    _videoOverlayEnabled = true;
    notifyListeners();
    await _saveSettings();
  }

  /// Clear settings when user signs out
  void clearForSignOut() {
    _userId = null;
    _videoOverlayEnabled = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _box?.close();
    super.dispose();
  }
}
