import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../ui_test_keys.dart';
import 'play_pause_button.dart';

/// Design-matched timer controls with reset, play/pause, and skip/complete buttons.
///
/// Layout matches Penpot design:
/// - Row with 24px spacing
/// - Reset button (48x48) on left
/// - Play/Pause button (72x72) in center
/// - Skip/Complete button (48x48) on right
class TimerControls extends StatelessWidget {
  final bool isRunning;
  final bool isPaused;
  final bool isIdle;
  final bool isCompleted;
  final bool isCountdown;
  final bool isRest;
  final bool isNextRest;
  final VoidCallback onPlayPause;
  final VoidCallback onReset;
  final VoidCallback? onSkip;
  final VoidCallback? onComplete;
  final VoidCallback? onSkipToRest;
  final VoidCallback? onSkipRest;

  /// Button dimensions from Penpot design
  static const double mainButtonSize = 72;
  static const double secondaryButtonSize = 48;
  static const double buttonSpacing = 40;

  const TimerControls({
    super.key,
    required this.isRunning,
    required this.isPaused,
    required this.isIdle,
    required this.isCompleted,
    this.isCountdown = false,
    this.isRest = false,
    this.isNextRest = false,
    required this.onPlayPause,
    required this.onReset,
    this.onSkip,
    this.onComplete,
    this.onSkipToRest,
    this.onSkipRest,
  });

  @override
  Widget build(BuildContext context) {
    // Show coffee button instead of reset when next interval is rest
    final coffeeButton = _buildLeftSecondaryButton();

    return FlexibleTimerControls(
      spacing: buttonSpacing,
      placeholderSize: secondaryButtonSize,
      leftButton: coffeeButton ?? _buildResetButton(),
      centerButton: _buildPlayPauseButton(),
      rightButton: _buildRightButton(),
    );
  }

  Widget _buildResetButton() {
    // Disable reset while timer is running (allow when paused, idle, or completed)
    final isDisabled = isRunning && !isPaused;
    return CircularControlButton(
      key: UiTestKeys.timerResetButton,
      icon: Icons.refresh,
      onPressed: isDisabled ? () {} : onReset,
      size: secondaryButtonSize,
      backgroundColor: AppColors.inputBackground,
      iconColor: AppColors.textSecondary,
      disabled: isDisabled,
    );
  }

  Widget _buildPlayPauseButton() {
    if (isCompleted) {
      return PlayPauseButton(
        key: UiTestKeys.timerPlayPauseButton,
        isPlaying: false,
        onPressed: onPlayPause,
        size: mainButtonSize,
        backgroundColor: AppColors.success,
        iconColor: AppColors.textPrimary,
        playIcon: Icons.check,
        pauseIcon: Icons.check,
        gradient: null,
      );
    }

    return PlayPauseButton(
      key: UiTestKeys.timerPlayPauseButton,
      isPlaying: isRunning,
      onPressed: onPlayPause,
      size: mainButtonSize,
    );
  }

  Widget? _buildRightButton() {
    // Always show stop button when onComplete is available
    if (onComplete != null) {
      final isDisabled = isCountdown || isIdle || isCompleted;

      return CircularControlButton(
        key: UiTestKeys.timerStopButton,
        icon: Icons.stop,
        onPressed: isDisabled ? () {} : onComplete!,
        size: secondaryButtonSize,
        backgroundColor: AppColors.inputBackground,
        iconColor: AppColors.error,
        disabled: isDisabled,
      );
    }

    // Fallback: Skip button when available and not completed
    if (onSkip != null && !isCompleted) {
      return CircularControlButton(
        icon: Icons.skip_next,
        onPressed: onSkip!,
        size: secondaryButtonSize,
        backgroundColor: AppColors.inputBackground,
        iconColor: AppColors.textSecondary,
      );
    }

    return null;
  }

  Widget? _buildLeftSecondaryButton() {
    // Always show reset button when paused or completed
    if (isPaused || isCompleted) {
      return null; // Will fall through to show reset button
    }

    // Skip rest button (start next round) when in rest interval
    if (isRest && onSkipRest != null) {
      return CircularControlButton(
        icon: Icons.skip_next,
        onPressed: onSkipRest!,
        size: secondaryButtonSize,
        backgroundColor: AppColors.timerWork.withValues(alpha: 0.2),
        iconColor: AppColors.timerWork,
      );
    }

    // Coffee button (skip to rest) when next interval is rest
    // Show when next is rest, but only enable when actually running (not countdown, not paused)
    if (isNextRest && onSkipToRest != null) {
      final isDisabled = !isRunning || isCountdown;
      return CircularControlButton(
        icon: Icons.coffee,
        onPressed: isDisabled ? () {} : onSkipToRest!,
        size: secondaryButtonSize,
        backgroundColor: AppColors.timerRest.withValues(alpha: 0.2),
        iconColor: AppColors.timerRest,
        disabled: isDisabled,
      );
    }
    return null;
  }
}

/// Compact timer controls for smaller UI contexts
class CompactTimerControls extends StatelessWidget {
  final bool isRunning;
  final bool isPaused;
  final bool isIdle;
  final bool isCompleted;
  final bool isCountdown;
  final bool isRest;
  final bool isNextRest;
  final VoidCallback onPlayPause;
  final VoidCallback onReset;
  final VoidCallback? onStop;
  final VoidCallback? onSkipToRest;
  final VoidCallback? onSkipRest;

  /// Compact button sizes
  static const double mainButtonSize = 52;
  static const double secondaryButtonSize = 36;
  static const double buttonSpacing = 32;

  const CompactTimerControls({
    super.key,
    required this.isRunning,
    this.isPaused = false,
    this.isIdle = false,
    this.isCompleted = false,
    this.isCountdown = false,
    this.isRest = false,
    this.isNextRest = false,
    required this.onPlayPause,
    required this.onReset,
    this.onStop,
    this.onSkipToRest,
    this.onSkipRest,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Left button: reset, coffee, or skip rest
        _buildLeftButton(),
        const SizedBox(width: buttonSpacing),
        // Center: play/pause or checkmark when completed
        _buildPlayPauseButton(),
        const SizedBox(width: buttonSpacing),
        // Right: stop button
        if (onStop != null) _buildStopButton(),
      ],
    );
  }

  Widget _buildLeftButton() {
    // Always show reset button when paused or completed
    if (isPaused || isCompleted) {
      return _buildResetButton();
    }

    // Skip rest button (start next round) when in rest interval
    if (isRest && onSkipRest != null) {
      return CircularControlButton(
        icon: Icons.skip_next,
        onPressed: onSkipRest!,
        size: secondaryButtonSize,
        backgroundColor: AppColors.timerWork.withValues(alpha: 0.2),
        iconColor: AppColors.timerWork,
      );
    }

    // Coffee button (skip to rest) when next interval is rest
    if (isNextRest && onSkipToRest != null) {
      final isDisabled = !isRunning || isCountdown;
      return CircularControlButton(
        icon: Icons.coffee,
        onPressed: isDisabled ? () {} : onSkipToRest!,
        size: secondaryButtonSize,
        backgroundColor: AppColors.timerRest.withValues(alpha: 0.2),
        iconColor: AppColors.timerRest,
        disabled: isDisabled,
      );
    }

    return _buildResetButton();
  }

  Widget _buildResetButton() {
    // Disable reset while timer is running (allow when paused, idle, or completed)
    final isDisabled = isRunning && !isPaused;
    return CircularControlButton(
      key: UiTestKeys.timerResetButton,
      icon: Icons.refresh,
      onPressed: isDisabled ? () {} : onReset,
      size: secondaryButtonSize,
      backgroundColor: AppColors.inputBackground,
      iconColor: AppColors.textSecondary,
      disabled: isDisabled,
    );
  }

  Widget _buildPlayPauseButton() {
    if (isCompleted) {
      return PlayPauseButton(
        key: UiTestKeys.timerPlayPauseButton,
        isPlaying: false,
        onPressed: onPlayPause,
        size: mainButtonSize,
        backgroundColor: AppColors.success,
        iconColor: AppColors.textPrimary,
        playIcon: Icons.check,
        pauseIcon: Icons.check,
        gradient: null,
      );
    }

    return PlayPauseButton(
      key: UiTestKeys.timerPlayPauseButton,
      isPlaying: isRunning,
      onPressed: onPlayPause,
      size: mainButtonSize,
    );
  }

  Widget _buildStopButton() {
    final isDisabled = isCountdown || isIdle || isCompleted;
    return CircularControlButton(
      key: UiTestKeys.timerStopButton,
      icon: Icons.stop,
      onPressed: isDisabled ? () {} : onStop!,
      size: secondaryButtonSize,
      backgroundColor: AppColors.inputBackground,
      iconColor: AppColors.error,
      disabled: isDisabled,
    );
  }
}
