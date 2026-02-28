import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/workout.dart';
import '../../services/audio_service.dart';
import '../../widgets/timer/circular_timer_ring.dart';
import '../../widgets/timer/timer_controls.dart';
import '../../widgets/timer/movement_list.dart';
import '../../widgets/timer/pulsing_ring.dart';
import '../auth/login_screen.dart';

class TimerScreen extends StatefulWidget {
  final VoidCallback? onNavigateToManual;

  const TimerScreen({super.key, this.onNavigateToManual});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _workoutNameController = TextEditingController();
  final _audioService = AudioService();

  // Save workout state
  bool _isSaving = false;
  bool _isSaved = false;
  bool _savedOffline = false;
  bool _showSaveSuccess = false;
  String? _saveError;

  // Offline state
  bool _isOffline = false;

  // Notes expanded state
  bool _notesExpanded = false;

  @override
  void initState() {
    super.initState();
    // Sync initial input
    final workout = context.read<WorkoutProvider>();
    _inputController.text = workout.workoutInput;
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final connectivity = await Connectivity().checkConnectivity();
    setState(() {
      _isOffline = connectivity == ConnectivityResult.none;
    });
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOffline = result == ConnectivityResult.none;
      });
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _workoutNameController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  String _generateDefaultWorkoutName(Workout workout) {
    final type = workout.type.displayName.toUpperCase();
    final date = DateTime.now();
    final month = _monthName(date.month);
    return '$type - $month ${date.day}';
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  void _showSaveWorkoutModal(BuildContext context, WorkoutProvider workout) {
    final currentWorkout = workout.currentWorkout!;
    _workoutNameController.text = _generateDefaultWorkoutName(currentWorkout);
    _saveError = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Save Workout', style: AppTextStyles.h3),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Workout Name',
                style: AppTextStyles.label,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _workoutNameController,
                decoration: const InputDecoration(
                  hintText: 'Enter workout name',
                ),
                onSubmitted: (_) => _handleSaveWorkout(context, workout, setModalState),
              ),
              if (_saveError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withValues(alpha:0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _saveError!,
                          style: AppTextStyles.body.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving || _workoutNameController.text.trim().isEmpty
                          ? null
                          : () => _handleSaveWorkout(context, workout, setModalState),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textPrimary,
                              ),
                            )
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSaveWorkout(
    BuildContext context,
    WorkoutProvider workout,
    void Function(void Function()) setModalState,
  ) async {
    final name = _workoutNameController.text.trim();
    if (name.isEmpty || workout.currentWorkout == null) return;

    setModalState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      // Create a copy of the workout with the new name
      final workoutToSave = Workout(
        id: workout.currentWorkout!.id,
        userId: workout.currentWorkout!.userId,
        name: name,
        rawInput: workout.currentWorkout!.rawInput,
        type: workout.currentWorkout!.type,
        timerConfig: workout.currentWorkout!.timerConfig,
        movements: workout.currentWorkout!.movements,
        createdAt: workout.currentWorkout!.createdAt,
        isFavorite: false,
      );

      await workout.saveWorkout(workoutToSave);

      setState(() {
        _isSaved = true;
        _savedOffline = _isOffline;
        _showSaveSuccess = true;
      });

      if (context.mounted) {
        Navigator.pop(context);
      }

      // Clear success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showSaveSuccess = false;
          });
        }
      });
    } catch (e) {
      setModalState(() {
        _saveError = e.toString();
      });
    } finally {
      setModalState(() {
        _isSaving = false;
      });
    }
  }

  void _resetSaveState() {
    setState(() {
      _isSaved = false;
      _savedOffline = false;
      _showSaveSuccess = false;
      _saveError = null;
      _notesExpanded = false;
    });
  }

  void _handleWakeLock(WorkoutProvider workout) {
    if (workout.isRunning || workout.isRest) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canSave = auth.isAuthenticated;

    return Consumer<WorkoutProvider>(
      builder: (context, workout, _) {
        // Handle wake lock
        _handleWakeLock(workout);

        return Scaffold(
          appBar: workout.currentWorkout != null
              ? AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      workout.clearWorkout();
                      _resetSaveState();
                      widget.onNavigateToManual?.call();
                    },
                  ),
                  title: Text(
                    workout.currentWorkout!.type.displayName.toUpperCase(),
                  ),
                  actions: [
                    // Offline indicator
                    if (_isOffline)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_off,
                              size: 14,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Offline',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Save button (only when not already saved)
                    if (canSave && !_isSaved)
                      IconButton(
                        icon: const Icon(Icons.bookmark_border),
                        tooltip: 'Save workout',
                        onPressed: () => _showSaveWorkoutModal(context, workout),
                      ),
                    // Saved indicator
                    if (_isSaved)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(
                          Icons.check_circle,
                          color: AppColors.success,
                        ),
                      ),
                    // Voice toggle button
                    IconButton(
                      icon: Icon(
                        _audioService.isMuted ? Icons.volume_off : Icons.volume_up,
                      ),
                      tooltip: _audioService.isMuted ? 'Unmute' : 'Mute',
                      onPressed: () {
                        setState(() {
                          _audioService.toggleMute();
                        });
                      },
                    ),
                  ],
                )
              : AppBar(
                  title: const Text('AI Workout Timer'),
                  actions: [
                    // Sign in / Profile button
                    _buildAuthButton(context, auth),
                  ],
                ),
          body: SafeArea(
            child: Column(
              children: [
                // Save success toast
                if (_showSaveSuccess)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _savedOffline
                          ? AppColors.warning.withValues(alpha:0.2)
                          : AppColors.success.withValues(alpha:0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _savedOffline
                            ? AppColors.warning.withValues(alpha:0.3)
                            : AppColors.success.withValues(alpha:0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _savedOffline ? Icons.cloud_off : Icons.check_circle,
                          color: _savedOffline ? AppColors.warning : AppColors.success,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _savedOffline
                                ? 'Saved offline. Will sync when online.'
                                : 'Workout saved successfully!',
                            style: AppTextStyles.body.copyWith(
                              color: _savedOffline ? AppColors.warning : AppColors.success,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setState(() {
                              _showSaveSuccess = false;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                // Main content
                Expanded(
                  child: workout.currentWorkout == null
                      ? _buildInputView(context, workout)
                      : _buildTimerView(context, workout),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Auth button - shows sign in or profile menu
  Widget _buildAuthButton(BuildContext context, AuthProvider auth) {
    if (auth.isAuthenticated) {
      // Show profile menu for authenticated users
      return PopupMenuButton<String>(
        icon: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
        onSelected: (value) async {
          if (value == 'signout') {
            await auth.signOut();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              auth.user?.email ?? '',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'signout',
            child: Row(
              children: [
                Icon(Icons.logout, size: 20),
                SizedBox(width: 8),
                Text('Sign Out'),
              ],
            ),
          ),
        ],
      );
    } else {
      // Show sign in button for unauthenticated users
      return IconButton(
        icon: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_outline,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
      );
    }
  }

  /// Input view for workout parsing
  Widget _buildInputView(BuildContext context, WorkoutProvider workout) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section label
          Text(
            'Your Workout',
            style: AppTextStyles.h4,
          ),
          const SizedBox(height: 12),

          // Input field
          TextField(
            controller: _inputController,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'Paste your workout here...\n\nExample:\nAMRAP 20min:\n10 Wall Balls (20/14 lbs)\n10 Box Jumps (24/20 in)\n10 Burpees',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              workout.setWorkoutInput(value);
            },
          ),

          const SizedBox(height: 16),

          // Error message
          if (workout.parseError != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      workout.parseError!,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Create Timer button - matches Manual Timer's Start Timer button
          ElevatedButton(
            onPressed: workout.isParsing ? null : () => workout.parseWorkout(),
            child: workout.isParsing
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Creating...'),
                    ],
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome),
                      SizedBox(width: 8),
                      Text('Create Timer'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerView(BuildContext context, WorkoutProvider workout) {
    final currentWorkout = workout.currentWorkout!;

    return Stack(
      children: [
        // Main content
        SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Timer ring (tappable for manual counter)
              GestureDetector(
                onTap: workout.shouldShowManualCounter && workout.isRunning
                    ? () => workout.incrementCounter()
                    : null,
                child: PulsingRing(
                  size: 260,
                  enabled: workout.shouldShowManualCounter && workout.isRunning,
                  color: AppColors.primary,
                  child: AnimatedTimerRing(
                    progress: workout.progress,
                    time: workout.formattedTime,
                    progressColor: _getTimerColor(workout),
                    size: 260,
                    centerWidget: _buildTimerCenterContent(workout, currentWorkout),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Timer controls
              TimerControls(
                isRunning: workout.isRunning || workout.isRest || workout.isCountdown,
                isPaused: workout.isPaused,
                isIdle: workout.isIdle,
                isCompleted: workout.isCompleted,
                isCountdown: workout.isCountdown,
                isRest: workout.isRest,
                isNextRest: workout.isNextRest && workout.isCurrentWork,
                onPlayPause: () {
                  workout.toggleTimer();
                },
                onReset: () {
                  workout.resetTimer();
                },
                onSkip: currentWorkout.movements.isNotEmpty
                    ? () => workout.skipMovement()
                    : null,
                onComplete: () {
                  workout.completeEarly();
                },
                onSkipToRest: workout.isNextRest
                    ? () => workout.completeCurrentInterval()
                    : null,
                onSkipRest: workout.isRest
                    ? () => workout.completeCurrentInterval()
                    : null,
              ),

              const SizedBox(height: 32),

              // Current movement display
              if (currentWorkout.movements.isNotEmpty) ...[
                CurrentMovementDisplay(
                  current: workout.currentMovement,
                  next: workout.nextMovement,
                ),
                const SizedBox(height: 24),
                MovementList(
                  movements: currentWorkout.movements,
                  currentIndex: workout.currentMovementIndex,
                ),
              ],

            ],
          ),
        ),

        // Notes toggle and panel (slides up from bottom)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                )),
                child: child,
              );
            },
            child: _notesExpanded
                ? _buildNotesPanel(currentWorkout.notes ?? '')
                : _buildNotesToggle(currentWorkout.notes ?? ''),
          ),
        ),
      ],
    );
  }

  Widget? _buildTimerCenterContent(WorkoutProvider workout, Workout currentWorkout) {
    final showRoundCounter = workout.shouldShowRoundCounter;
    final showRounds = workout.totalRounds > 1 && currentWorkout.type != WorkoutType.workRest && !showRoundCounter;
    final isWorkRest = currentWorkout.type == WorkoutType.workRest;
    final showManualCounter = workout.shouldShowManualCounter;

    // If nothing extra to show, return null (default time display)
    if (!showRounds && !isWorkRest && !showManualCounter && !showRoundCounter) return null;

    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Timer strictly centered
          Text(
            workout.formattedTime,
            style: AppTextStyles.timerLarge.copyWith(
              fontSize: 260 * 0.22,
              fontWeight: FontWeight.w700,
            ),
          ),
          // Round/Rest counter (for interval-based timers with work and rest)
          if (showRoundCounter)
            Positioned(
              bottom: 260 * 0.22,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Round ${workout.currentWorkRound}/${workout.totalWorkRounds}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: workout.isCurrentWork && !workout.isIdle && !workout.isCountdown
                          ? AppColors.timerWork
                          : AppColors.textMuted,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Container(
                      width: 1,
                      height: 12,
                      color: AppColors.border,
                    ),
                  ),
                  Text(
                    'Rest ${workout.currentRestRound}/${workout.totalRestRounds}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: workout.isCurrentRest
                          ? AppColors.timerRest
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            )
          // Other bottom text (Total, Round X of Y, Counter)
          else if (isWorkRest)
            Positioned(
              bottom: 260 * 0.28,
              child: Text(
                'Total: ${workout.formattedElapsedTime}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            )
          else if (showRounds)
            Positioned(
              bottom: 260 * 0.28,
              child: Text(
                'Round ${workout.currentRound} of ${workout.totalRounds}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            )
          else if (showManualCounter)
            Positioned(
              bottom: 260 * 0.28,
              child: Text(
                'Counter: ${workout.counter}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getTimerColor(WorkoutProvider workout) {
    if (workout.isCountdown) {
      return AppColors.timerCountdown;
    }
    if (workout.isRest) {
      return AppColors.timerRest;
    }
    if (workout.isCompleted) {
      return AppColors.timerComplete;
    }
    return AppColors.timerWork;
  }

  Widget _buildNotesToggle(String notes) {
    return GestureDetector(
      key: const ValueKey('notes_toggle'),
      onTap: () {
        setState(() {
          _notesExpanded = true;
        });
      },
      child: const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            Icon(
              Icons.keyboard_arrow_up,
              color: AppColors.textMuted,
              size: 20,
            ),
            Text(
              'Show notes',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesPanel(String notes) {
    return Container(
      key: const ValueKey('notes_panel'),
      width: double.infinity,
      constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.28),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hide notes button
            Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _notesExpanded = false;
                  });
                },
                child: const Column(
                  children: [
                    Text(
                      'Hide notes',
                      style: AppTextStyles.bodySmall,
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Notes content
            Flexible(
              child: SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    notes.isEmpty ? 'No notes' : notes,
                    textAlign: TextAlign.left,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: notes.isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
