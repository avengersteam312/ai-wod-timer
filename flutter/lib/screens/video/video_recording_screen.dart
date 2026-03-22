import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../providers/video_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../../ui_test_keys.dart';
import '../../widgets/video/camera_preview.dart';
import '../../widgets/video/timer_overlay.dart';
import '../../widgets/video/recording_controls.dart';
import '../../widgets/video/zoom_control.dart';
import 'video_preview_screen.dart';

/// Main video recording screen with camera preview and timer overlay
/// Supports swipe right to go to timer, swipe left to come back
class VideoRecordingScreen extends StatefulWidget {
  const VideoRecordingScreen({
    super.key,
    this.videoPreviewBuilder,
  });

  final Widget Function(String videoPath)? videoPreviewBuilder;

  @override
  State<VideoRecordingScreen> createState() => _VideoRecordingScreenState();
}

class _VideoRecordingScreenState extends State<VideoRecordingScreen>
    with WidgetsBindingObserver {
  Timer? _recordingTimer;
  bool _isDraggingOverlay = false;

  // Swipe animation state
  double _swipeOffset = 0;
  bool _isSwiping = false;

  // Track last captured display time to avoid duplicates
  String? _lastCapturedDisplayTime;

  // Store reference for listener removal
  WorkoutProvider? _workoutProvider;

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

      // Listen to workout timer changes for frame capture synced with audio
      _workoutProvider = context.read<WorkoutProvider>();
      _workoutProvider?.addListener(_onWorkoutChanged);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _workoutProvider?.removeListener(_onWorkoutChanged);
    WakelockPlus.disable();
    super.dispose();
  }

  /// Called when workout state changes - syncs recording duration and captures frames
  void _onWorkoutChanged() {
    // Check if widget is still mounted
    if (!mounted) return;

    final videoProvider = context.read<VideoProvider>();
    final workoutProvider = context.read<WorkoutProvider>();

    if (!videoProvider.isRecording ||
        videoProvider.recordingStartTime == null) {
      return;
    }

    // Update recording duration synced with workout timer tick
    final timestamp = DateTime.now().difference(videoProvider.recordingStartTime!);
    videoProvider.updateRecordingDuration(timestamp);

    // Only capture frames if workout exists
    if (workoutProvider.currentWorkout == null) return;

    // Only capture when display time changes (avoids duplicates)
    final displayTime = workoutProvider.formattedTime;
    if (displayTime == _lastCapturedDisplayTime) return;
    _lastCapturedDisplayTime = displayTime;

    // Capture frame with current recording timestamp (synced with beep)
    videoProvider.captureTimerFrame(
      TimerFrame(
        timestamp: timestamp,
        displayTime: displayTime,
        progress: workoutProvider.progress,
        roundIndicator: _getRoundIndicator(workoutProvider),
        isRest: workoutProvider.isRest,
        isWork: workoutProvider.isRunning,
        recordingTime: _formatRecordingTime(timestamp),
      ),
    );
  }

  String _formatRecordingTime(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
      if (videoProvider.isRecording &&
          videoProvider.recordingStartTime != null) {
        final duration =
            DateTime.now().difference(videoProvider.recordingStartTime!);

        final workoutProvider = context.read<WorkoutProvider>();
        final isTimerActive = workoutProvider.isRunning ||
            workoutProvider.isRest ||
            workoutProvider.isCountdown;

        // Only update recording duration here when workout timer is NOT active
        // (when active, it's synced via _onWorkoutChanged listener)
        if (!isTimerActive) {
          videoProvider.updateRecordingDuration(duration);

          // Capture frames to keep overlay visible when timer is paused
          if (workoutProvider.currentWorkout != null) {
            videoProvider.captureTimerFrame(
              TimerFrame(
                timestamp: duration,
                displayTime: workoutProvider.formattedTime,
                progress: workoutProvider.progress,
                roundIndicator: _getRoundIndicator(workoutProvider),
                isRest: workoutProvider.isRest,
                isWork: false,
                recordingTime: _formatRecordingTime(duration),
              ),
            );
          }
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
      final round =
          (workout.isIdle || workout.isCountdown) ? 0 : workout.currentRound;
      return '$round/${workout.totalRounds}';
    }
    return null;
  }

  Future<void> _startRecording() async {
    final videoProvider = context.read<VideoProvider>();
    final workoutProvider = context.read<WorkoutProvider>();

    await videoProvider.startRecording();
    if (videoProvider.isRecording) {
      // Reset frame tracking
      _lastCapturedDisplayTime = null;

      // Capture initial frame immediately at timestamp 0
      if (workoutProvider.currentWorkout != null) {
        _lastCapturedDisplayTime = workoutProvider.formattedTime;
        videoProvider.captureTimerFrame(
          TimerFrame(
            timestamp: Duration.zero,
            displayTime: workoutProvider.formattedTime,
            progress: workoutProvider.progress,
            roundIndicator: _getRoundIndicator(workoutProvider),
            isRest: workoutProvider.isRest,
            isWork: workoutProvider.isRunning,
            recordingTime: '00:00',
          ),
        );
      }
      _startRecordingTimer();
    }
  }

  void _stopTimer() {
    final workoutProvider = context.read<WorkoutProvider>();
    workoutProvider.pauseTimer();
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    final videoProvider = context.read<VideoProvider>();
    final timerFrames = List<TimerFrame>.from(videoProvider.timerFrames);
    final recordingDate = videoProvider.recordingStartTime;
    final rawPath = await videoProvider.stopRecording();

    // Dispose camera after stopping recording
    videoProvider.disposeCamera();

    if (rawPath != null && mounted) {
      videoProvider.setProcessedVideoPath(rawPath);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                widget.videoPreviewBuilder?.call(rawPath) ??
                VideoPreviewScreen(
                  videoPath: rawPath,
                  timerFrames: timerFrames,
                  recordingDate: recordingDate,
                ),
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

  void _handleOverlayDrag(
      DragUpdateDetails details, VideoProvider videoProvider) {
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
        // Timer is "active" for button display: running, rest, or countdown (not paused)
        final isTimerActive = workoutProvider.isRunning ||
            workoutProvider.isRest ||
            workoutProvider.isCountdown;

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
                _swipeOffset =
                    (_swipeOffset + details.delta.dx).clamp(0.0, screenWidth);
              });
            }
          },
          onHorizontalDragEnd: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            final swipeThreshold = screenWidth * 0.5;

            // Swipe right → go to timer (animate off screen first)
            if (_swipeOffset >= swipeThreshold ||
                (details.primaryVelocity != null &&
                    details.primaryVelocity! > 300)) {
              final navigator = Navigator.of(context);
              setState(() {
                _swipeOffset = screenWidth;
                _isSwiping = false;
              });
              Future.delayed(const Duration(milliseconds: 200), () {
                if (mounted) {
                  navigator.pop();
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
            duration:
                _isSwiping ? Duration.zero : const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_swipeOffset, 0, 0),
            child: Scaffold(
              key: UiTestKeys.videoScreen,
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
                            time: (workoutProvider.isIdle ||
                                    workoutProvider.isCountdown ||
                                    workoutProvider.isCompleted)
                                ? workoutProvider.formattedInitialTime
                                : workoutProvider.formattedTime,
                            progress: workoutProvider.progress,
                            style: videoProvider.overlayStyle,
                            size: videoProvider.overlaySizePixels,
                            progressColor: _getTimerColor(workoutProvider),
                            roundIndicator: _getRoundIndicator(workoutProvider),
                            isRest: workoutProvider.isRest,
                            isDragging: _isDraggingOverlay,
                            onDragStart: () =>
                                setState(() => _isDraggingOverlay = true),
                            onDragUpdate: (details) =>
                                _handleOverlayDrag(details, videoProvider),
                            onDragEnd: () =>
                                _handleOverlayDragEnd(videoProvider),
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

                  // Zoom control (above recording controls) - animate hide during recording
                  if (videoProvider.isInitialized &&
                      videoProvider.zoomPresets.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 160,
                      child: Center(
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
                          child: videoProvider.isRecording
                              ? const SizedBox.shrink(key: ValueKey('hidden'))
                              : ZoomControl(
                                  key: const ValueKey('zoom'),
                                  currentZoom: videoProvider.currentZoom,
                                  presets: videoProvider.zoomPresets,
                                  onZoomChanged: videoProvider.setZoom,
                                  enabled: !videoProvider.isProcessing,
                                ),
                        ),
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
                      onStartTimer: () {
                        workoutProvider.startTimer();
                        // Restart recording timer to sync with workout timer
                        _startRecordingTimer();
                      },
                      onStopTimer: _stopTimer,
                      onFlipCamera: videoProvider.isRecording
                          ? null
                          : videoProvider.flipCamera,
                      onClose: videoProvider.isRecording ? null : _handleClose,
                    ),
                  ),

                  // Swipe hint (left edge) - Swipe right for timer
                  const Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _VerticalSwipeHint(
                        text: 'Swipe right for timer',
                        isLeft: true,
                      ),
                    ),
                  ),

                  // Loading overlay
                  if (videoProvider.isInitializing ||
                      videoProvider.isProcessing)
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
