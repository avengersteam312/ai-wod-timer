import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

enum HapticType {
  light,
  medium,
  heavy,
  selection,
  success,
  warning,
  error,
}

class HapticsService {
  static final HapticsService _instance = HapticsService._internal();
  factory HapticsService() => _instance;
  HapticsService._internal();

  static HapticsService get instance => _instance;

  bool _isEnabled = true;

  bool get isEnabled => _isEnabled;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  Future<void> trigger(HapticType type) async {
    if (!_isEnabled) return;

    // Skip haptics on web
    if (kIsWeb) return;

    try {
      switch (type) {
        case HapticType.light:
          await HapticFeedback.lightImpact();
          break;
        case HapticType.medium:
          await HapticFeedback.mediumImpact();
          break;
        case HapticType.heavy:
          await HapticFeedback.heavyImpact();
          break;
        case HapticType.selection:
          await HapticFeedback.selectionClick();
          break;
        case HapticType.success:
          await HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.lightImpact();
          break;
        case HapticType.warning:
          await HapticFeedback.heavyImpact();
          break;
        case HapticType.error:
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.heavyImpact();
          break;
      }
    } catch (e) {
      debugPrint('Haptic feedback not supported: $e');
    }
  }

  Future<void> buttonTap() => trigger(HapticType.light);

  Future<void> selectionChanged() => trigger(HapticType.selection);

  Future<void> actionTriggered() => trigger(HapticType.medium);

  Future<void> timerAlert() => trigger(HapticType.heavy);

  Future<void> countdown() => trigger(HapticType.medium);

  Future<void> workoutComplete() => trigger(HapticType.success);
}
