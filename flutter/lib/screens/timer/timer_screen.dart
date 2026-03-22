import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../app_bootstrap.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workout_provider.dart';
import '../../providers/video_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/workout.dart';
import '../../services/audio_service.dart';
import '../../services/sync_service.dart';
import '../../ui_test_keys.dart';
import '../../utils/workout_name.dart';
import '../../screens/workouts/my_workouts_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../widgets/auth_button.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/timer/circular_timer_ring.dart';
import '../../widgets/timer/timer_controls.dart';
import '../../widgets/save_template_modal.dart';
import '../../utils/snackbar_utils.dart';
import '../../screens/video/video_recording_screen.dart';

enum NotesState { closed, minimized, full }

enum DashboardCreateMode { text, image }

class TimerScreen extends StatefulWidget {
  final VoidCallback? onNavigateToManual;
  final VoidCallback? onNavigateToManualForEdit;

  /// True when the Dashboard tab is selected (used to refresh saved workouts when returning to tab).
  final bool isDashboardVisible;

  /// Callback to show/hide the delete zone in AppShell (covers nav bar)
  final void Function(bool show, {void Function(Workout)? onDelete})?
      onDragStateChanged;
  final SyncService? syncService;
  final ImagePicker? imagePicker;
  final VideoPreviewBuilder? videoPreviewBuilder;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const TimerScreen({
    super.key,
    this.onNavigateToManual,
    this.onNavigateToManualForEdit,
    this.isDashboardVisible = true,
    this.onDragStateChanged,
    this.syncService,
    this.imagePicker,
    this.videoPreviewBuilder,
    this.scaffoldKey,
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _audioService = AudioService();

  // Save workout state
  bool _isSaved = false;

  /// When true, after save or "Don't save" we go back to input view.
  bool _saveThenExit = false;

  // Saved timers (dashboard) state
  List<Workout> _savedWorkouts = [];
  bool _savedWorkoutsLoading = false;
  bool _savedWorkoutsLoaded = false;
  String? _savedWorkoutsError;

  // Offline state
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Notes state: closed, minimized, full
  NotesState _notesState = NotesState.closed;
  bool _isNotesExiting = false;

  // Swipe to edit animation
  double _swipeOffset = 0;
  bool _isSwipingToEdit = false;

  static const int _maxSavedWorkoutsDisplay = 9;

  DashboardCreateMode _createMode = DashboardCreateMode.text;

  SyncService get _syncService => widget.syncService ?? SyncService();

  ImagePicker get _imagePicker => widget.imagePicker ?? ImagePicker();

  @override
  void initState() {
    super.initState();
    // Sync initial input
    final workout = context.read<WorkoutProvider>();
    _inputController.text = workout.workoutInput;
    _checkConnectivity();
    final userId = context.read<AuthProvider>().user?.id;
    if (userId != null) {
      _loadSavedWorkouts(userId);
    }
  }

  @override
  void didUpdateWidget(covariant TimerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh saved workouts when user returns to Dashboard tab so list is up to date
    final becameVisible =
        widget.isDashboardVisible && !oldWidget.isDashboardVisible;
    if (becameVisible && mounted) {
      // Clear old status messages
      setState(() {});
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        _loadSavedWorkouts(userId);
      }
    }
  }

  Future<void> _loadSavedWorkouts(String userId) async {
    if (_savedWorkoutsLoading) return;
    setState(() {
      _savedWorkoutsLoading = true;
      _savedWorkoutsError = null;
    });
    try {
      final workouts = await _syncService.getWorkouts(userId);
      if (mounted) {
        setState(() {
          _savedWorkouts = workouts;
          _savedWorkoutsLoading = false;
          _savedWorkoutsLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _savedWorkoutsError = e.toString();
          _savedWorkouts = [];
          _savedWorkoutsLoading = false;
          _savedWorkoutsLoaded = true;
        });
      }
    }
  }

  Future<void> _checkConnectivity() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() {
      _isOffline =
          connectivity.every((result) => result == ConnectivityResult.none);
    });
    // Listen for connectivity changes
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      if (!mounted) return;
      setState(() {
        _isOffline = result.every((entry) => entry == ConnectivityResult.none);
      });
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _goBackToInput(WorkoutProvider workout) {
    workout.clearWorkout();
    _inputController.clear();
    setState(() {
      _isSaved = false;
      _saveThenExit = false;
    });
  }

  /// Handle Stop button press: complete and stay on screen.
  void _handleStopTimer(BuildContext context, WorkoutProvider workout) {
    // Complete the timer and stay on screen
    workout.completeEarly();
  }

  /// Open save prompt when ending session (X button).
  void _openEndSessionSavePrompt(
      BuildContext context, WorkoutProvider workout) {
    // If workout is still running, pause it first
    if (workout.isRunning || workout.isRest || workout.isCountdown) {
      workout.pauseTimer();
    }
    // If loaded from saved workouts, just go back (already saved)
    if (workout.loadedFromWorkoutId != null) {
      _goBackToInput(workout);
      return;
    }
    final auth = context.read<AuthProvider>();
    // Show save prompt for authenticated users (unless already saved)
    if (auth.isAuthenticated && workout.currentWorkout != null && !_isSaved) {
      _saveThenExit = true;
      _showSaveWorkoutModal(workout);
    } else {
      _goBackToInput(workout);
    }
  }

  /// Open save modal without exiting (e.g. from Save button in app bar).
  void _openSaveModal(BuildContext context, WorkoutProvider workout) {
    if (workout.currentWorkout == null) return;
    _saveThenExit = false;
    _showSaveWorkoutModal(workout);
  }

  Future<void> _showSaveWorkoutModal(WorkoutProvider workout) async {
    final currentWorkout = workout.currentWorkout!;
    final userId = context.read<AuthProvider>().user?.id;
    final shouldExitAfterSave = _saveThenExit;

    final saved = await SaveTemplateModal.show(
      context: context,
      defaultName: proposeWorkoutName(currentWorkout),
      onCheckNameTaken: userId != null
          ? (name) => workout
              .isWorkoutNameTaken(
                userId,
                name,
                excludeWorkoutId: workout.loadedFromWorkoutId,
              )
              .timeout(const Duration(seconds: 10), onTimeout: () => false)
          : null,
      onSave: (name) async {
        final workoutToSave = Workout(
          id: currentWorkout.id,
          userId: currentWorkout.userId,
          name: name,
          rawInput: currentWorkout.rawInput,
          type: currentWorkout.type,
          timerConfig: currentWorkout.timerConfig,
          movements: currentWorkout.movements,
          createdAt: currentWorkout.createdAt,
          isFavorite: false,
        );
        await workout
            .saveWorkout(workoutToSave)
            .timeout(const Duration(seconds: 10));
        return true;
      },
      onSaveSuccess: () {
        _isSaved = true;
        if (userId != null && mounted) {
          _loadSavedWorkouts(userId);
        }
      },
    );

    // Handle "save then exit" flow
    if (saved && shouldExitAfterSave) {
      _saveThenExit = false;
      _goBackToInput(workout);
    } else if (!saved && shouldExitAfterSave) {
      // User cancelled - still exit without saving
      _saveThenExit = false;
      _goBackToInput(workout);
    }
  }

  Future<void> _pickImage(ImageSource source, WorkoutProvider workout) async {
    try {
      // Optimized for token efficiency:
      // - 70% quality is sufficient for text extraction
      // - 1536px max matches GPT-4o-mini "auto" detail threshold
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1536,
        maxHeight: 1536,
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        await workout.parseWorkoutFromImage(imageFile);
        if (mounted && workout.parseError != null) {
          AppSnackBar.showError(context, workout.parseError!);
        }
      }
    } catch (e) {
      debugPrint('[TimerScreen] Image picker error: $e');
      if (mounted) {
        AppSnackBar.showError(context, 'Failed to pick image');
      }
    }
  }

  List<Workout> get _prioritizedSavedWorkouts {
    final workouts = List<Workout>.from(_savedWorkouts);
    workouts.sort((a, b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }

      final bTimestamp = _primaryWorkoutTimestamp(b);
      final aTimestamp = _primaryWorkoutTimestamp(a);
      final byDate = bTimestamp.compareTo(aTimestamp);
      if (byDate != 0) return byDate;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return workouts;
  }

  DateTime _primaryWorkoutTimestamp(Workout workout) {
    return workout.updatedAt ?? workout.createdAt;
  }

  bool _ensureAuthenticated() {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) return true;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    return false;
  }

  String _activeWorkoutStateLabel(WorkoutProvider workout) {
    if (workout.isCompleted) return 'Completed';
    if (workout.isPaused) return 'Paused';
    if (workout.isCountdown) return 'Countdown';
    if (workout.isRest) return 'Rest';
    if (workout.isRunning) return 'In progress';
    return 'Ready to start';
  }

  String _combineNotesWithDescription(Workout workout) {
    final description = workout.rawInput?.trim() ?? '';
    final notes = workout.notes?.trim() ?? '';

    if (description.isEmpty && notes.isEmpty) {
      return '';
    }
    if (description.isEmpty) {
      return notes;
    }
    if (notes.isEmpty) {
      return description;
    }
    return '$description\n\n---\n\n$notes';
  }

  void _handleWakeLock(WorkoutProvider workout) {
    if (workout.isRunning || workout.isRest) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  void _openVideoScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoRecordingScreen(
          videoPreviewBuilder: widget.videoPreviewBuilder,
        ),
      ),
    );
  }

  void _openEditTimer(WorkoutProvider workout) {
    if (!workout.isIdle || widget.onNavigateToManualForEdit == null) {
      return;
    }
    workout.setPendingEdit(workout.currentWorkout!);
    widget.onNavigateToManualForEdit!();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canSave = auth.isAuthenticated;

    return Consumer2<WorkoutProvider, VideoProvider>(
      builder: (context, workout, videoProvider, _) {
        // Handle wake lock
        _handleWakeLock(workout);

        // When on timer view and authenticated, ensure we have saved workouts so we can hide Save when config already exists
        if (workout.currentWorkout != null &&
            auth.isAuthenticated &&
            auth.user != null &&
            !_savedWorkoutsLoading &&
            !_savedWorkoutsLoaded &&
            _savedWorkoutsError == null &&
            _savedWorkouts.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final userId = context.read<AuthProvider>().user?.id;
              if (userId != null) _loadSavedWorkouts(userId);
            }
          });
        }

        return Scaffold(
          key: widget.scaffoldKey,
          drawer: const AppDrawer(),
          drawerEnableOpenDragGesture: false,
          appBar: workout.currentWorkout != null && !workout.showInputOverride
              ? AppBar(
                  automaticallyImplyLeading: false,
                  leading: IconButton(
                    key: UiTestKeys.timerCancelButton,
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel timer',
                    onPressed: () =>
                        _openEndSessionSavePrompt(context, workout),
                  ),
                  title: Text(
                    workout.currentWorkout!.type.displayName.toUpperCase(),
                  ),
                  actions: [
                    // Recording indicator (only when recording)
                    if (videoProvider.isRecording)
                      GestureDetector(
                        onTap: _openVideoScreen,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: _RecordingDot(),
                        ),
                      ),
                    // Save button for authenticated users (hide for already saved timers)
                    if (canSave && workout.loadedFromWorkoutId == null)
                      IconButton(
                        key: UiTestKeys.manualSaveButton,
                        icon: const Icon(Icons.save_outlined),
                        tooltip: 'Save timer',
                        onPressed: () => _openSaveModal(context, workout),
                      ),
                    // Offline indicator
                    if (_isOffline)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
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
                    // Voice toggle button (only affects voice, not beeps)
                    IconButton(
                      icon: Icon(
                        _audioService.isMuted
                            ? Icons.voice_over_off
                            : Icons.record_voice_over,
                      ),
                      tooltip:
                          _audioService.isMuted ? 'Enable voice' : 'Mute voice',
                      onPressed: () {
                        setState(() {
                          _audioService.toggleMute();
                        });
                      },
                    ),
                  ],
                )
              : AppBar(
                  leading: const MenuButton(),
                  title: const Text('AI Workout Timer'),
                ),
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    // Main content
                    Expanded(
                      child: (workout.currentWorkout == null ||
                              workout.showInputOverride)
                          ? _buildInputView(context, workout)
                          : GestureDetector(
                              onHorizontalDragStart: (_) {
                                setState(() => _isSwipingToEdit = true);
                              },
                              onHorizontalDragUpdate: (details) {
                                if (_isSwipingToEdit) {
                                  final screenWidth =
                                      MediaQuery.of(context).size.width;
                                  setState(() {
                                    _swipeOffset =
                                        (_swipeOffset + details.delta.dx).clamp(
                                      -screenWidth, // Always allow swipe left for camera
                                      workout.isIdle
                                          ? screenWidth
                                          : 0.0, // Only allow swipe right when idle
                                    );
                                  });
                                }
                              },
                              onHorizontalDragEnd: (details) {
                                final screenWidth =
                                    MediaQuery.of(context).size.width;
                                final swipeThreshold = screenWidth * 0.5;
                                final navigator = Navigator.of(context);

                                // Swipe right -> open adjust timer (only when idle)
                                if ((_swipeOffset >= swipeThreshold ||
                                        (details.primaryVelocity != null &&
                                            details.primaryVelocity! > 300)) &&
                                    workout.isIdle &&
                                    widget.onNavigateToManualForEdit != null) {
                                  setState(() {
                                    _swipeOffset = screenWidth;
                                    _isSwipingToEdit = false;
                                  });
                                  Future.delayed(
                                      const Duration(milliseconds: 200), () {
                                    if (mounted) {
                                      _openEditTimer(workout);
                                      setState(() => _swipeOffset = 0);
                                    }
                                  });
                                  return;
                                }

                                // Swipe left -> open camera
                                if (_swipeOffset <= -swipeThreshold ||
                                    (details.primaryVelocity != null &&
                                        details.primaryVelocity! < -300)) {
                                  setState(() {
                                    _swipeOffset = -screenWidth;
                                    _isSwipingToEdit = false;
                                  });
                                  Future.delayed(
                                      const Duration(milliseconds: 200), () {
                                    if (mounted) {
                                      navigator.push(
                                        PageRouteBuilder(
                                          pageBuilder: (context, animation,
                                                  secondaryAnimation) =>
                                              VideoRecordingScreen(
                                            videoPreviewBuilder:
                                                widget.videoPreviewBuilder,
                                          ),
                                          transitionsBuilder: (context,
                                                  animation,
                                                  secondaryAnimation,
                                                  child) =>
                                              child,
                                        ),
                                      );
                                      setState(() => _swipeOffset = 0);
                                    }
                                  });
                                  return;
                                }

                                setState(() {
                                  _swipeOffset = 0;
                                  _isSwipingToEdit = false;
                                });
                              },
                              onHorizontalDragCancel: () {
                                setState(() {
                                  _swipeOffset = 0;
                                  _isSwipingToEdit = false;
                                });
                              },
                              child: AnimatedContainer(
                                duration: _isSwipingToEdit
                                    ? Duration.zero
                                    : const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                transform: Matrix4.translationValues(
                                    _swipeOffset, 0, 0),
                                child: _buildTimerView(
                                    context, workout, videoProvider),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Input view for workout parsing
  Widget _buildInputView(BuildContext context, WorkoutProvider workout) {
    final auth = context.watch<AuthProvider>();
    if (auth.isAuthenticated &&
        auth.user != null &&
        _savedWorkouts.isEmpty &&
        !_savedWorkoutsLoading &&
        !_savedWorkoutsLoaded &&
        _savedWorkoutsError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSavedWorkouts(auth.user!.id);
      });
    }

    final prioritizedSaved = _prioritizedSavedWorkouts;
    final displayedSaved =
        prioritizedSaved.take(_maxSavedWorkoutsDisplay).toList();
    final hasSavedTimers = auth.isAuthenticated &&
        _savedWorkoutsLoaded &&
        prioritizedSaved.isNotEmpty;

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (workout.currentWorkout != null) ...[
                  _buildActiveWorkoutCard(workout),
                  const SizedBox(height: 24),
                ],
                _buildCreateTimerCard(context, workout, auth.isAuthenticated),
                if (auth.isAuthenticated) ...[
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Saved timers',
                        style: AppTextStyles.label,
                      ),
                      if (prioritizedSaved.isNotEmpty)
                        GestureDetector(
                          key: UiTestKeys.dashboardViewAllSavedWorkouts,
                          onTap: () async {
                            final authProvider = context.read<AuthProvider>();
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MyWorkoutsScreen(
                                  onNavigateToTimer: () =>
                                      Navigator.pop(context),
                                  syncService: widget.syncService,
                                ),
                              ),
                            );
                            if (mounted) {
                              final userId = authProvider.user?.id;
                              if (userId != null) {
                                _loadSavedWorkouts(userId);
                              }
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View all',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_savedWorkoutsLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    )
                  else if (_savedWorkoutsError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _savedWorkoutsError!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    )
                  else if (hasSavedTimers)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedSaved.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.25,
                      ),
                      itemBuilder: (context, index) {
                        final savedWorkout = displayedSaved[index];
                        return LongPressDraggable<Workout>(
                          data: savedWorkout,
                          onDragStarted: () {
                            widget.onDragStateChanged
                                ?.call(true, onDelete: _deleteWorkoutDirectly);
                          },
                          onDragEnd: (_) {
                            widget.onDragStateChanged?.call(false);
                          },
                          onDraggableCanceled: (_, __) {
                            widget.onDragStateChanged?.call(false);
                          },
                          feedback: LayoutBuilder(
                            builder: (context, constraints) {
                              // Calculate item width based on grid: 3 columns, 10px spacing, 20px padding each side
                              final screenWidth =
                                  MediaQuery.of(context).size.width;
                              final itemWidth = (screenWidth - 40 - 20) / 3;
                              return Material(
                                color: Colors.transparent,
                                child: SizedBox(
                                  width: itemWidth,
                                  height: itemWidth / 1.25,
                                  child: _SavedTimerQuickCard(
                                    workout: savedWorkout,
                                    onTap: () {},
                                  ),
                                ),
                              );
                            },
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.25,
                            child: _SavedTimerQuickCard(
                              workout: savedWorkout,
                              onTap: () {},
                            ),
                          ),
                          child: _SavedTimerQuickCard(
                            workout: savedWorkout,
                            cardKey: UiTestKeys.dashboardSavedWorkout(
                                savedWorkout.id),
                            onTap: () {
                              workout.setWorkout(
                                savedWorkout,
                                fromSavedWorkoutId: savedWorkout.id,
                              );
                              workout.setShowInputOverride(false);
                            },
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        'No saved timers yet. Your reusable templates will show up here.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveWorkoutCard(WorkoutProvider workout) {
    final currentWorkout = workout.currentWorkout!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current timer',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentWorkout.name,
                      style: AppTextStyles.h4,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _activeWorkoutStateLabel(workout),
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    (workout.isIdle || workout.isCountdown)
                        ? workout.formattedInitialTime
                        : workout.formattedTime,
                    style: AppTextStyles.h3.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    workout.isCompleted ? 'Done' : 'Tap to resume',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: UiTestKeys.dashboardResumeButton,
              onPressed: () {
                workout.setShowInputOverride(false);
              },
              icon: const Icon(Icons.play_circle_outline),
              label: Text(
                workout.isCompleted
                    ? 'View completed timer'
                    : 'Resume current timer',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateTimerCard(
    BuildContext context,
    WorkoutProvider workout,
    bool isAuthenticated,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.cardBackground,
            AppColors.cardBackground,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCreateModeToggle(),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 200),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _createMode == DashboardCreateMode.text
                  ? _buildTextCreationPane(context, workout, isAuthenticated)
                  : _buildImageCreationPane(context, workout, isAuthenticated),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DashboardModeButton(
              buttonKey: UiTestKeys.dashboardTextModeToggle,
              label: 'Write',
              icon: Icons.edit_outlined,
              isSelected: _createMode == DashboardCreateMode.text,
              onTap: () {
                setState(() {
                  _createMode = DashboardCreateMode.text;
                });
              },
            ),
          ),
          Expanded(
            child: _DashboardModeButton(
              buttonKey: UiTestKeys.dashboardImageModeToggle,
              label: 'Photo',
              icon: Icons.photo_camera_outlined,
              isSelected: _createMode == DashboardCreateMode.image,
              onTap: () {
                setState(() {
                  _createMode = DashboardCreateMode.image;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextCreationPane(
    BuildContext context,
    WorkoutProvider workout,
    bool isAuthenticated,
  ) {
    final isBusy = workout.isParsing || workout.isExtractingFromImage;

    return Column(
      key: const ValueKey('dashboard_text_mode'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: UiTestKeys.dashboardTextInput,
          controller: _inputController,
          minLines: 3,
          maxLines: 10,
          decoration: InputDecoration(
            hintText: 'Paste or describe a workout to create a timer',
            alignLabelWithHint: true,
            fillColor: AppColors.inputBackground.withValues(alpha: 0.9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onChanged: (value) {
            workout.setWorkoutInput(value);
          },
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            key: UiTestKeys.dashboardCreateTimerButton,
            onPressed: isBusy
                ? null
                : () async {
                    if (!isAuthenticated && !_ensureAuthenticated()) return;
                    await workout.parseWorkout();
                    if (!context.mounted) return;
                    if (workout.parseError != null) {
                      AppSnackBar.showError(context, workout.parseError!);
                    }
                  },
            icon: isBusy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textPrimary,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(isBusy ? 'Creating...' : 'Create timer'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageCreationPane(
    BuildContext context,
    WorkoutProvider workout,
    bool isAuthenticated,
  ) {
    final isBusy = workout.isParsing || workout.isExtractingFromImage;

    Widget buildAction({
      Key? buttonKey,
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          key: buttonKey,
          onPressed: isBusy
              ? null
              : () {
                  if (!isAuthenticated && !_ensureAuthenticated()) return;
                  onTap();
                },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.buttonSmall),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey('dashboard_image_mode'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildAction(
          buttonKey: UiTestKeys.dashboardTakePhotoButton,
          icon: Icons.photo_camera_outlined,
          title: 'Take photo',
          subtitle: 'Use the camera for a new whiteboard photo.',
          onTap: () => _pickImage(ImageSource.camera, workout),
        ),
        const SizedBox(height: 12),
        buildAction(
          buttonKey: UiTestKeys.dashboardChooseGalleryButton,
          icon: Icons.photo_library_outlined,
          title: 'Choose from gallery',
          subtitle: 'Import an existing image or screenshot.',
          onTap: () => _pickImage(ImageSource.gallery, workout),
        ),
        if (isBusy) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Reading your image...',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Delete workout directly (used by drag-to-delete, no confirmation needed)
  Future<void> _deleteWorkoutDirectly(Workout workout) async {
    try {
      await _syncService.deleteWorkout(workout.id);
      setState(() {
        _savedWorkouts.removeWhere((w) => w.id == workout.id);
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Failed to delete');
      }
    }
  }

  Widget _buildTimerView(BuildContext context, WorkoutProvider workout,
      VideoProvider videoProvider) {
    final currentWorkout = workout.currentWorkout!;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Swipe hint - left (edit timer, inactive when running)
        Positioned(
          left: 8,
          top: 32 + 100, // Align with timer numbers
          child: GestureDetector(
            key: UiTestKeys.timerEditAction,
            onTap: workout.isIdle ? () => _openEditTimer(workout) : null,
            child: Opacity(
              opacity: workout.isIdle ? 1.0 : 0.5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      'Swipe right to adjust',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Swipe hint - right (camera)
        Positioned(
          right: 8,
          top: 32 + 100, // Align with timer numbers
          child: GestureDetector(
            key: UiTestKeys.timerCameraAction,
            onTap: _openVideoScreen,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const RotatedBox(
                  quarterTurns: 1,
                  child: Text(
                    'Swipe left for camera',
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Main content
        SingleChildScrollView(
          controller: _scrollController,
          physics: _notesState != NotesState.closed
              ? const NeverScrollableScrollPhysics()
              : null,
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            children: [
              // Timer ring (tappable for manual counter)
              SizedBox(
                width: 320,
                height: 320,
                child: Center(
                  child: GestureDetector(
                    onTap: workout.shouldShowManualCounter && workout.isRunning
                        ? () => workout.incrementCounter()
                        : null,
                    child: AnimatedTimerRing(
                      progress: workout.progress,
                      time: workout.formattedTime,
                      progressColor: _getTimerColor(workout),
                      size: 300,
                      isAnimating: workout.isRunning ||
                          workout.isRest ||
                          workout.isCountdown,
                      centerWidget:
                          _buildTimerCenterContent(workout, currentWorkout),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Timer controls (only show inline when notes not expanded)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      )),
                      child: child,
                    ),
                  );
                },
                child: _notesState != NotesState.closed
                    ? const SizedBox.shrink()
                    : TimerControls(
                        key: const ValueKey('inline_controls'),
                        isRunning: workout.isRunning ||
                            workout.isRest ||
                            workout.isCountdown,
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
                          _handleStopTimer(context, workout);
                        },
                        onSkipToRest: workout.isNextRest
                            ? () => workout.completeCurrentInterval()
                            : null,
                        onSkipRest: workout.isRest
                            ? () => workout.completeCurrentInterval()
                            : null,
                      ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),

        // Notes toggle and panel (slides up from bottom)
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          left: 0,
          right: 0,
          bottom: 0,
          // Full: cover entire screen, Minimized: start below clock, Closed: anchor to bottom
          top: _notesState == NotesState.full
              ? 0
              : (_notesState == NotesState.minimized ? 400 : null),
          child: Column(
            mainAxisSize: _notesState != NotesState.closed
                ? MainAxisSize.max
                : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Notes toggle (only when closed)
              if (_notesState == NotesState.closed)
                _buildNotesToggle(_combineNotesWithDescription(currentWorkout)),
              // Single animated notes panel containing timer, controls, and notes content
              if (_notesState != NotesState.closed)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      // Only animate slide when opening or closing completely
                      // Full → Minimized is handled by AnimatedPositioned
                      final isExitingToClose = _isNotesExiting &&
                          _notesState == NotesState.minimized;
                      return TweenAnimationBuilder<double>(
                        key: ValueKey(
                            'notes_panel_${isExitingToClose ? 'closing' : 'open'}'),
                        duration: const Duration(milliseconds: 300),
                        tween: Tween<double>(
                          begin: isExitingToClose ? 0.0 : 1.0,
                          end: isExitingToClose ? 1.0 : 0.0,
                        ),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          final screenHeight =
                              MediaQuery.of(context).size.height;
                          return Transform.translate(
                            offset: Offset(0, value * screenHeight * 0.6),
                            child: child,
                          );
                        },
                        child: _buildUnifiedNotesPanel(
                          workout,
                          _combineNotesWithDescription(currentWorkout),
                          _notesState == NotesState.full,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _buildTimerCenterContent(
      WorkoutProvider workout, Workout currentWorkout) {
    final showRoundCounter = workout.shouldShowRoundCounter;
    final showRounds = workout.totalRounds > 1 &&
        currentWorkout.type != WorkoutType.workRest &&
        !showRoundCounter;
    final isWorkRest = currentWorkout.type == WorkoutType.workRest;
    final showManualCounter = workout.shouldShowManualCounter;

    // If nothing extra to show, return null (default time display)
    if (!showRounds && !isWorkRest && !showManualCounter && !showRoundCounter) {
      return null;
    }

    const double timerSize = 300;
    return SizedBox(
      width: timerSize,
      height: timerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Timer strictly centered
          Text(
            workout.formattedTime,
            style: AppTextStyles.timerLarge.copyWith(
              fontSize: timerSize * 0.22,
              fontWeight: FontWeight.w700,
            ),
          ),
          // Round/Rest counter (for interval-based timers with work and rest)
          if (showRoundCounter) ...[
            Positioned(
              bottom: timerSize * 0.22,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Round ${workout.currentWorkRound}/${workout.totalWorkRounds}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: workout.isCurrentWork &&
                              !workout.isIdle &&
                              !workout.isCountdown
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
            ),
            // Total time display
            Positioned(
              top: timerSize * 0.18,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total: ${workout.formattedElapsedTime}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Work: ${workout.formattedTotalWorkTime}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ]
          // Other bottom text (Total, Round X of Y, Counter)
          else if (isWorkRest)
            Positioned(
              bottom: timerSize * 0.24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total: ${workout.formattedElapsedTime}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Work: ${workout.formattedTotalWorkTime}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            )
          else if (showRounds) ...[
            Positioned(
              bottom: timerSize * 0.28,
              child: Text(
                'Round ${workout.isIdle || workout.isCountdown ? 0 : workout.currentRound} of ${workout.totalRounds}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Positioned(
              top: workout.totalRestRounds > 0
                  ? timerSize * 0.18
                  : timerSize * 0.22,
              child: workout.totalRestRounds > 0
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total: ${workout.formattedElapsedTime}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Work: ${workout.formattedTotalWorkTime}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Total: ${workout.formattedElapsedTime}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
            ),
          ] else if (showManualCounter) ...[
            Positioned(
              bottom: timerSize * 0.28,
              child: Text(
                'Counter: ${workout.counter}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            // Tap icon hint with text
            Positioned(
              top: timerSize * 0.18,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.touch_app,
                    size: 28,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to count',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          _notesState = NotesState.minimized;
        });
      },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -300) {
          // Swipe up - open notes to minimized (half)
          setState(() {
            _notesState = NotesState.minimized;
          });
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(bottom: 16),
        color: Colors.transparent,
        child: Column(
          children: [
            // Drag handle indicator
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Swipe up for notes',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedNotesPanel(
      WorkoutProvider workout, String notes, bool isFull) {
    final notesContent = SingleChildScrollView(
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          notes,
          textAlign: TextAlign.left,
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.textPrimary,
            height: 1.5,
          ),
        ),
      ),
    );

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: isFull,
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Swipe handle + Hide notes button
            GestureDetector(
              onVerticalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity > 300) {
                  // Swipe down - minimize or close
                  if (_notesState == NotesState.full) {
                    setState(() {
                      _notesState = NotesState.minimized;
                    });
                  } else {
                    setState(() {
                      _isNotesExiting = true;
                    });
                    Future.delayed(const Duration(milliseconds: 350), () {
                      if (mounted) {
                        setState(() {
                          _isNotesExiting = false;
                          _notesState = NotesState.closed;
                        });
                      }
                    });
                  }
                } else if (velocity < -300) {
                  // Swipe up - maximize
                  if (_notesState == NotesState.minimized) {
                    setState(() {
                      _notesState = NotesState.full;
                    });
                  }
                }
              },
              onTap: () {
                if (_notesState == NotesState.full) {
                  setState(() {
                    _notesState = NotesState.minimized;
                  });
                } else {
                  setState(() {
                    _isNotesExiting = true;
                  });
                  Future.delayed(const Duration(milliseconds: 350), () {
                    if (mounted) {
                      setState(() {
                        _isNotesExiting = false;
                        _notesState = NotesState.closed;
                      });
                    }
                  });
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: Colors.transparent,
                child: Column(
                  children: [
                    // Drag handle indicator
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textMuted,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isFull ? 'Swipe down to minimize' : 'Swipe up or down',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Notes content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: notesContent,
              ),
            ),
            // Compact timer (only when full)
            if (isFull)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 1),
                    bottom: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Center(
                  child: Text(
                    workout.formattedTime,
                    style: AppTextStyles.h1.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            // Compact controls (always when open)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: CompactTimerControls(
                isRunning:
                    workout.isRunning || workout.isRest || workout.isCountdown,
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
                onStop: () {
                  _handleStopTimer(context, workout);
                },
                onSkipToRest: workout.isNextRest
                    ? () => workout.completeCurrentInterval()
                    : null,
                onSkipRest: workout.isRest
                    ? () => workout.completeCurrentInterval()
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Key? buttonKey;

  const _DashboardModeButton({
    this.buttonKey,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.buttonSmall.copyWith(
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingDot extends StatelessWidget {
  const _RecordingDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SavedTimerQuickCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;
  final Key? cardKey;

  const _SavedTimerQuickCard({
    this.cardKey,
    required this.workout,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: cardKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              if (workout.isFavorite)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    Icons.star,
                    size: 16,
                    color: Colors.amber,
                  ),
                ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayWorkoutName(workout.name),
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          workout.formattedDuration,
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
