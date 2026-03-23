import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../ui_test_keys.dart';

/// Recording controls for video capture
class RecordingControls extends StatelessWidget {
  final bool isRecording;
  final bool isTimerRunning;
  final Duration recordingDuration;
  final VoidCallback? onStartRecording;
  final VoidCallback? onStopRecording;
  final VoidCallback? onStartTimer;
  final VoidCallback? onStopTimer;
  final VoidCallback? onFlipCamera;
  final VoidCallback? onClose;

  const RecordingControls({
    super.key,
    required this.isRecording,
    this.isTimerRunning = false,
    this.recordingDuration = Duration.zero,
    this.onStartRecording,
    this.onStopRecording,
    this.onStartTimer,
    this.onStopTimer,
    this.onFlipCamera,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Close button - animate hide/show during recording
            SizedBox(
              width: 48,
              height: 48,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: isRecording
                    ? const SizedBox.shrink(key: ValueKey('hidden'))
                    : _ControlButton(
                        key: UiTestKeys.videoCloseButton,
                        icon: Icons.close,
                        onTap: onClose,
                        size: 48,
                      ),
              ),
            ),

            // Main action button with animation:
            // - Not recording: Show Record button
            // - Recording + timer running: Show Stop Timer button
            // - Recording + timer not running: Show Stop Recording button
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: !isRecording
                  ? _RecordButton(
                      key: UiTestKeys.videoRecordButton,
                      onTap: onStartRecording,
                    )
                  : isTimerRunning
                      ? _StopTimerButton(
                          key: const ValueKey('stopTimer'),
                          onTap: onStopTimer,
                        )
                      : _StopButton(
                          key: UiTestKeys.videoStopButton,
                          onTap: onStopRecording,
                        ),
            ),

            // Flip camera button - animate hide/show during recording
            SizedBox(
              width: 48,
              height: 48,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: FadeTransition(
                      opacity: animation,
                      child: child,
                    ),
                  );
                },
                child: isRecording
                    ? const SizedBox.shrink(key: ValueKey('hidden'))
                    : _ControlButton(
                        key: const ValueKey('flip'),
                        icon: Icons.flip_camera_ios,
                        onTap: onFlipCamera,
                        size: 48,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered play button for starting timer (neutral color, vertically centered)
class CenteredPlayButton extends StatelessWidget {
  final VoidCallback? onTap;

  const CenteredPlayButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 48,
        ),
      ),
    );
  }
}

/// Recording time indicator (minimalistic - just dot and time, no background)
class RecordingTimeIndicator extends StatefulWidget {
  final Duration duration;

  const RecordingTimeIndicator({super.key, required this.duration});

  @override
  State<RecordingTimeIndicator> createState() => _RecordingTimeIndicatorState();
}

class _RecordingTimeIndicatorState extends State<RecordingTimeIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing red dot
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: _animation.value),
                shape: BoxShape.circle,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        // Duration text
        Text(
          _formatDuration(widget.duration),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Record button (red circle)
class _RecordButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _RecordButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.error,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Stop button (rounded square inside circle)
class _StopButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _StopButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
        ),
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stop Timer button (square inside circle, same as stop recording but different color)
class _StopTimerButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _StopTimerButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
        ),
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.timerWork,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}

/// Control button (close, flip, etc.)
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  const _ControlButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }
}
