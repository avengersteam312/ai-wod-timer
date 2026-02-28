import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../providers/workout_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/audio_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/timer/timer_widgets.dart';

/// Work/Rest Timer Screen
/// Demonstrates composition of reusable timer widgets
class WorkRestTimerScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const WorkRestTimerScreen({super.key, this.onBack});

  @override
  State<WorkRestTimerScreen> createState() => _WorkRestTimerScreenState();
}

class _WorkRestTimerScreenState extends State<WorkRestTimerScreen> {
  final _audioService = AudioService();
  bool _showWorkoutDetails = false;

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  void _handleWakeLock(WorkoutProvider workout) {
    if (workout.isRunning || workout.isRest) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  Color get _workColor => const Color(0xFFFF6D00); // Orange for work
  Color get _restColor => AppColors.success; // Green for rest

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, workout, _) {
        _handleWakeLock(workout);

        final isRestPhase = workout.isRest;
        final activeColor = isRestPhase ? _restColor : _workColor;
        final currentWorkout = workout.currentWorkout;

        return TimerScaffold(
          title: 'WORK_REST',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              workout.clearWorkout();
              widget.onBack?.call();
            },
          ),
          actions: [
            TimerAppBarActions(
              showSave: currentWorkout != null,
              showSound: true,
              showProfile: true,
              isMuted: _audioService.isMuted,
              onSave: () {
                // Handle save
              },
              onToggleSound: () {
                setState(() {
                  _audioService.toggleMute();
                });
              },
              profileButton: _buildProfileButton(context),
            ),
          ],
          timerSection: _buildTimerSection(workout, activeColor),
          indicatorSection: _buildPhaseIndicator(workout),
          controlsSection: _buildControls(workout, activeColor),
          expandableSection: _buildExpandableWorkout(workout),
          completedSection: _buildCompletedSection(workout),
          isCompleted: workout.isCompleted,
        );
      },
    );
  }

  Widget _buildTimerSection(WorkoutProvider workout, Color activeColor) {
    final isRestPhase = workout.isRest;
    final label = workout.isCountdown
        ? 'GET READY'
        : (isRestPhase ? 'REST' : 'WORK');

    return AnimatedTimerRing(
      progress: workout.progress,
      time: workout.formattedTime,
      progressColor: activeColor,
      size: 280,
      isAnimating: workout.isRunning || workout.isRest || workout.isCountdown,
      centerWidget: TimerDisplay(
        time: workout.formattedTime,
        label: label,
        labelColor: activeColor,
        subLabel: 'Total: ${workout.formattedElapsedTime}',
        timeSize: 56,
      ),
    );
  }

  Widget _buildPhaseIndicator(WorkoutProvider workout) {
    final currentRound = workout.currentRound;
    final totalRounds = workout.totalRounds;
    final isRestPhase = workout.isRest;

    // Calculate rest count (completed rests)
    final restCount = currentRound > 0 ? currentRound - 1 : 0;

    return TimerPhaseIndicator(
      segments: [
        PhaseSegment(
          label: 'ROUND',
          count: '$currentRound/$totalRounds',
        ),
        PhaseSegment(
          label: 'REST',
          count: '$restCount/$totalRounds',
        ),
      ],
      activeIndex: isRestPhase ? 1 : 0,
      activeColor: isRestPhase ? _restColor : _workColor,
    );
  }

  Widget _buildControls(WorkoutProvider workout, Color activeColor) {
    return FlexibleTimerControls(
      leftButton: CircularControlButton(
        icon: Icons.refresh,
        onPressed: () => workout.resetTimer(),
      ),
      centerButton: PlayPauseButton(
        isPlaying: workout.isRunning || workout.isRest,
        onPressed: () => workout.toggleTimer(),
        backgroundColor: activeColor,
        gradient: null,
      ),
      rightButton: CircularControlButton(
        icon: Icons.stop,
        iconColor: AppColors.error,
        onPressed: () => workout.completeEarly(),
        disabled: workout.isIdle,
      ),
    );
  }

  Widget _buildExpandableWorkout(WorkoutProvider workout) {
    final config = workout.currentWorkout?.timerConfig;
    if (config == null) return const SizedBox.shrink();

    return ExpandableSection(
      title: 'Show workout',
      initiallyExpanded: _showWorkoutDetails,
      onToggle: () {
        setState(() {
          _showWorkoutDetails = !_showWorkoutDetails;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: WorkoutInfoCard(
          items: [
            WorkoutInfoItem(
              label: 'Work Time',
              value: '${config.workSeconds ?? 0}s',
              icon: Icons.fitness_center,
              iconColor: _workColor,
            ),
            WorkoutInfoItem(
              label: 'Rest Time',
              value: '${config.restSeconds ?? 0}s',
              icon: Icons.pause_circle_outline,
              iconColor: _restColor,
            ),
            WorkoutInfoItem(
              label: 'Rounds',
              value: '${config.rounds ?? 0}',
              icon: Icons.loop,
            ),
            WorkoutInfoItem(
              label: 'Total Time',
              value: _formatTotalTime(config),
              icon: Icons.timer,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedSection(WorkoutProvider workout) {
    return CompletionCard(
      title: 'Workout Complete!',
      elapsedTime: workout.formattedElapsedTime,
      accentColor: _workColor,
      onNewWorkout: () {
        workout.clearWorkout();
        widget.onBack?.call();
      },
    );
  }

  Widget _buildProfileButton(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return ProfileAvatarButton(
      email: auth.user?.email,
      onLogout: () => auth.signOut(),
    );
  }

  String _formatTotalTime(dynamic config) {
    final total = config.totalSeconds ?? 0;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
