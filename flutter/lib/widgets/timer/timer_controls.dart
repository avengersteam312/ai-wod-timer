import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
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
  static const double buttonSpacing = 24;

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
    return CircularControlButton(
      icon: Icons.refresh,
      onPressed: onReset,
      size: secondaryButtonSize,
      backgroundColor: AppColors.inputBackground,
      iconColor: AppColors.textSecondary,
    );
  }

  Widget _buildPlayPauseButton() {
    if (isCompleted) {
      return PlayPauseButton(
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
      isPlaying: isRunning,
      onPressed: onPlayPause,
      size: mainButtonSize,
    );
  }

  Widget? _buildRightButton() {
    // Skip button when available and not completed
    if (onSkip != null && !isCompleted) {
      return CircularControlButton(
        icon: Icons.skip_next,
        onPressed: onSkip!,
        size: secondaryButtonSize,
        backgroundColor: AppColors.inputBackground,
        iconColor: AppColors.textSecondary,
      );
    }

    // Stop button - always visible, only disabled during countdown
    if (onComplete != null) {
      final isDisabled = isCountdown || isIdle || isCompleted;

      return CircularControlButton(
        icon: Icons.stop,
        onPressed: isDisabled ? () {} : onComplete!,
        size: secondaryButtonSize,
        backgroundColor: AppColors.inputBackground,
        iconColor: AppColors.error,
        disabled: isDisabled,
      );
    }

    return null;
  }

  Widget? _buildLeftSecondaryButton() {
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
  final VoidCallback onPlayPause;
  final VoidCallback onReset;

  const CompactTimerControls({
    super.key,
    required this.isRunning,
    required this.onPlayPause,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularControlButton(
          icon: Icons.refresh,
          onPressed: onReset,
          size: 40,
          backgroundColor: AppColors.inputBackground,
          iconColor: AppColors.textSecondary,
        ),
        const SizedBox(width: 12),
        PlayPauseButton(
          isPlaying: isRunning,
          onPressed: onPlayPause,
          size: 48,
        ),
      ],
    );
  }
}
