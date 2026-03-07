import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../providers/video_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/video/camera_preview.dart';
import '../../widgets/video/timer_overlay.dart';
import '../../widgets/video/recording_controls.dart';
import 'video_preview_screen.dart';

/// Main video recording screen with camera preview and timer overlay
/// Supports swipe right to go to timer, swipe left to come back
class VideoRecordingScreen extends StatefulWidget {
  const VideoRecordingScreen({super.key});

  @override
  State<VideoRecordingScreen> createState() => _VideoRecordingScreenState();
}

class _VideoRecordingScreenState extends State<VideoRecordingScreen> with WidgetsBindingObserver {
  Timer? _recordingTimer;
  bool _isDraggingOverlay = false;

  // Swipe animation state
  double _swipeOffset = 0;
  bool _isSwiping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final videoProvider = context.read<VideoProvider>();
      // If already recording, just restart the timer (returning from timer screen)
      if (videoProvider.isRecording) {
        _startRecordingTimer();
      } else if (!videoProvider.isInitialized) {
        _initializeCamera();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final videoProvider = context.read<VideoProvider>();
    if (state == AppLifecycleState.resumed) {
      if (!videoProvider.isInitialized && !videoProvider.isRecording) {
        _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    final videoProvider = context.read<VideoProvider>();
    await videoProvider.initializeCamera();
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final videoProvider = context.read<VideoProvider>();
      if (videoProvider.isRecording && videoProvider.recordingStartTime != null) {
        final duration = DateTime.now().difference(videoProvider.recordingStartTime!);
        videoProvider.updateRecordingDuration(duration);

        final workoutProvider = context.read<WorkoutProvider>();
        if (workoutProvider.currentWorkout != null) {
          videoProvider.captureTimerFrame(
            TimerFrame(
              timestamp: duration,
              displayTime: workoutProvider.formattedTime,
              progress: workoutProvider.progress,
              roundIndicator: _getRoundIndicator(workoutProvider),
              isRest: workoutProvider.isRest,
              isWork: workoutProvider.isRunning,
            ),
          );
        }

        if (duration.inMinutes >= 10) {
          _stopRecording();
        }
      }
    });
  }

  String? _getRoundIndicator(WorkoutProvider workout) {
    if (workout.shouldShowRoundCounter) {
      if (workout.isRest) {
        return '${workout.currentRestRound}/${workout.totalRestRounds}';
      }
      return '${workout.currentWorkRound}/${workout.totalWorkRounds}';
    }
    if (workout.totalRounds > 1) {
      // Show 0 before timer starts (idle or countdown)
      final round = (workout.isIdle || workout.isCountdown) ? 0 : workout.currentRound;
      return '$round/${workout.totalRounds}';
    }
    return null;
  }

  Future<void> _startRecording() async {
    final videoProvider = context.read<VideoProvider>();
    await videoProvider.startRecording();
    if (videoProvider.isRecording) {
      _startRecordingTimer();
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    final videoProvider = context.read<VideoProvider>();
    final rawPath = await videoProvider.stopRecording();

    if (rawPath != null && mounted) {
      videoProvider.setProcessedVideoPath(rawPath);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VideoPreviewScreen(videoPath: rawPath),
          ),
        );
      }
    }
  }

  void _handleClose() {
    final videoProvider = context.read<VideoProvider>();
    if (videoProvider.isRecording) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: const Text('Stop Recording?'),
          content: const Text('This will discard the current recording.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                _recordingTimer?.cancel();
                await videoProvider.cameraController?.stopVideoRecording();
                videoProvider.reset();
                if (mounted) Navigator.pop(context);
              },
              child: const Text(
                'Discard',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
    } else {
      videoProvider.disposeCamera();
      Navigator.pop(context);
    }
  }

  void _handleOverlayDrag(DragUpdateDetails details, VideoProvider videoProvider) {
    final newPosition = Offset(
      videoProvider.overlayPosition.dx + details.delta.dx,
      videoProvider.overlayPosition.dy + details.delta.dy,
    );
    videoProvider.setOverlayPosition(newPosition);
  }

  void _handleOverlayDragEnd(VideoProvider videoProvider) {
    final screenSize = MediaQuery.of(context).size;
    videoProvider.constrainOverlayPosition(screenSize);
    setState(() => _isDraggingOverlay = false);
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Consumer2<VideoProvider, WorkoutProvider>(
      builder: (context, videoProvider, workoutProvider, _) {
        final isTimerActive = workoutProvider.isRunning ||
                              workoutProvider.isRest ||
                              workoutProvider.isCountdown ||
                              workoutProvider.isPaused;

        return GestureDetector(
          // Swipe right to go back to timer (keep recording)
          onHorizontalDragStart: (_) {
            setState(() => _isSwiping = true);
          },
          onHorizontalDragUpdate: (details) {
            if (_isSwiping) {
              final screenWidth = MediaQuery.of(context).size.width;
              setState(() {
                // Track right swipes (positive offset)
                _swipeOffset = (_swipeOffset + details.delta.dx).clamp(0.0, screenWidth);
              });
            }
          },
          onHorizontalDragEnd: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            final swipeThreshold = screenWidth * 0.5;

            // Swipe right → go to timer (animate off screen first)
            if (_swipeOffset >= swipeThreshold ||
                (details.primaryVelocity != null && details.primaryVelocity! > 300)) {
              setState(() {
                _swipeOffset = screenWidth;
                _isSwiping = false;
              });
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) {
                  Navigator.pop(context);
                }
              });
            } else {
              // Reset swipe state
              setState(() {
                _swipeOffset = 0;
                _isSwiping = false;
              });
            }
          },
          onHorizontalDragCancel: () {
            setState(() {
              _swipeOffset = 0;
              _isSwiping = false;
            });
          },
          child: AnimatedContainer(
            duration: _isSwiping ? Duration.zero : const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_swipeOffset, 0, 0),
            child: Scaffold(
            backgroundColor: AppColors.background,
            body: Stack(
              fit: StackFit.expand,
              children: [
                // Camera preview
                CameraPreview(
                  controller: videoProvider.cameraController,
                  isInitialized: videoProvider.isInitialized,
                  isFrontCamera: videoProvider.isFrontCamera,
                  isFlashOn: videoProvider.isFlashOn,
                ),

                // Top bar: Timer (left) and Recording time (right) on same line
                // Only show timer overlay when timer is running (not during countdown or idle)
                Positioned(
                  left: 20,
                  right: 20,
                  top: topPadding + 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timer overlay (left) - always show when workout exists
                      // During idle or countdown, show initial time instead of countdown
                      if (workoutProvider.currentWorkout != null)
                        TimerOverlay(
                          time: (workoutProvider.isIdle || workoutProvider.isCountdown)
                              ? workoutProvider.formattedInitialTime
                              : workoutProvider.formattedTime,
                          progress: workoutProvider.progress,
                          style: videoProvider.overlayStyle,
                          size: videoProvider.overlaySizePixels,
                          progressColor: _getTimerColor(workoutProvider),
                          roundIndicator: _getRoundIndicator(workoutProvider),
                          isRest: workoutProvider.isRest,
                          isDragging: _isDraggingOverlay,
                          onDragStart: () => setState(() => _isDraggingOverlay = true),
                          onDragUpdate: (details) => _handleOverlayDrag(details, videoProvider),
                          onDragEnd: () => _handleOverlayDragEnd(videoProvider),
                        )
                      else
                        const SizedBox(),

                      // Recording time indicator (right)
                      if (videoProvider.isRecording)
                        RecordingTimeIndicator(
                          duration: videoProvider.recordingDuration,
                        ),
                    ],
                  ),
                ),

                // Centered: play button OR countdown
                if (videoProvider.isRecording && !isTimerActive)
                  Center(
                    child: CenteredPlayButton(
                      onTap: () => workoutProvider.startTimer(),
                    ),
                  )
                else if (workoutProvider.isCountdown)
                  Center(
                    child: _CountdownDisplay(
                      seconds: workoutProvider.remainingSeconds,
                    ),
                  ),

                // Recording controls (bottom)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: RecordingControls(
                    isRecording: videoProvider.isRecording,
                    isTimerRunning: isTimerActive,
                    recordingDuration: videoProvider.recordingDuration,
                    onStartRecording: _startRecording,
                    onStopRecording: _stopRecording,
                    onStartTimer: () => workoutProvider.startTimer(),
                    onFlipCamera: videoProvider.isRecording ? null : videoProvider.flipCamera,
                    onClose: videoProvider.isRecording ? null : _handleClose,
                  ),
                ),

                // Swipe hint (left edge) - Swipe right for timer
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: const Center(
                    child: _VerticalSwipeHint(
                      text: 'Swipe right for timer',
                      isLeft: true,
                    ),
                  ),
                ),

                // Loading overlay
                if (videoProvider.isInitializing || videoProvider.isProcessing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.7),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            videoProvider.isProcessing
                                ? 'Processing video...'
                                : 'Initializing camera...',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Error overlay
                if (videoProvider.hasError)
                  Container(
                    color: Colors.black.withValues(alpha: 0.7),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            videoProvider.errorMessage ?? 'An error occurred',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              videoProvider.reset();
                              _initializeCamera();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  Color _getTimerColor(WorkoutProvider workout) {
    if (workout.isCountdown) return AppColors.timerCountdown;
    if (workout.isRest) return AppColors.timerRest;
    if (workout.isCompleted) return AppColors.timerComplete;
    return AppColors.timerWork;
  }
}

/// Countdown display shown in center before timer starts
class _CountdownDisplay extends StatelessWidget {
  final int seconds;

  const _CountdownDisplay({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$seconds',
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Vertical swipe hint (like "Swipe up for notes" but rotated for sides)
class _VerticalSwipeHint extends StatelessWidget {
  final String text;
  final bool isLeft;

  const _VerticalSwipeHint({
    required this.text,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: isLeft ? 3 : 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
