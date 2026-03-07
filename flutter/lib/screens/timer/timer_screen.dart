import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/workout.dart';
import '../../services/audio_service.dart';
import '../../services/sync_service.dart';
import '../../utils/workout_name.dart';
import '../../screens/workouts/my_workouts_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../widgets/auth_button.dart';
import '../../widgets/timer/circular_timer_ring.dart';
import '../../widgets/timer/timer_controls.dart';
import '../../widgets/save_template_modal.dart';
import '../../utils/snackbar_utils.dart';

enum NotesState { closed, minimized, full }

class TimerScreen extends StatefulWidget {
  final VoidCallback? onNavigateToManual;
  final VoidCallback? onNavigateToManualForEdit;
  /// True when the Dashboard tab is selected (used to refresh saved workouts when returning to tab).
  final bool isDashboardVisible;
  /// Callback to show/hide the delete zone in AppShell (covers nav bar)
  final void Function(bool show, {void Function(Workout)? onDelete})? onDragStateChanged;

  const TimerScreen({
    super.key,
    this.onNavigateToManual,
    this.onNavigateToManualForEdit,
    this.isDashboardVisible = true,
    this.onDragStateChanged,
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _audioService = AudioService();
  final _imagePicker = ImagePicker();

  // Save workout state
  bool _isSaved = false;
  /// When true, after save or "Don't save" we go back to input view.
  bool _saveThenExit = false;

  // Saved timers (dashboard) state
  final SyncService _syncService = SyncService();
  List<Workout> _savedWorkouts = [];
  bool _savedWorkoutsLoading = false;
  bool _savedWorkoutsLoaded = false;
  String? _savedWorkoutsError;

  // Offline state
  bool _isOffline = false;

  // Notes state: closed, minimized, full
  NotesState _notesState = NotesState.closed;
  bool _isNotesExiting = false;

  // Drag-to-delete state
  bool _isDraggingTimer = false;

  // Swipe to edit animation
  double _swipeOffset = 0;
  bool _isSwipingToEdit = false;

  static const int _maxSavedWorkoutsDisplay = 12;

  // Track previous parseError to detect changes
  String? _lastParseError;

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
    final becameVisible = widget.isDashboardVisible && !oldWidget.isDashboardVisible;
    if (becameVisible && mounted) {
      // Clear old status messages
      setState(() {
      });
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
  void _openEndSessionSavePrompt(BuildContext context, WorkoutProvider workout) {
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
          ? (name) => workout.isWorkoutNameTaken(
                userId,
                name,
                excludeWorkoutId: workout.loadedFromWorkoutId,
              ).timeout(const Duration(seconds: 10), onTimeout: () => false)
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
        await workout.saveWorkout(workoutToSave).timeout(const Duration(seconds: 10));
        return true;
      },
      onSaveSuccess: () {
        _isSaved = true;
        // Refresh saved workouts list
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

  void _showImagePickerModal(BuildContext context, WorkoutProvider workout) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Take Photo option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt, color: AppColors.primary),
                ),
                title: const Text('Take Photo'),
                subtitle: const Text('Use your camera'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickImage(ImageSource.camera, workout);
                },
              ),
              const SizedBox(height: 8),
              // Choose from Gallery option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library, color: AppColors.primary),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select an existing photo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickImage(ImageSource.gallery, workout);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
      }
    } catch (e) {
      debugPrint('[TimerScreen] Image picker error: $e');
      if (mounted) {
        AppSnackBar.showError(context, 'Failed to pick image');
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canSave = auth.isAuthenticated;

    return Consumer<WorkoutProvider>(
      builder: (context, workout, _) {
        // Handle wake lock
        _handleWakeLock(workout);

        // Show error snackbar when parseError changes
        final parseError = workout.parseError;
        if (parseError != null && parseError != _lastParseError) {
          _lastParseError = parseError;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              AppSnackBar.showError(context, parseError);
            }
          });
        } else if (parseError == null && _lastParseError != null) {
          _lastParseError = null;
        }

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
          appBar: workout.currentWorkout != null && !workout.showInputOverride
              ? AppBar(
                  automaticallyImplyLeading: false,
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel timer',
                    onPressed: () => _openEndSessionSavePrompt(context, workout),
                  ),
                  title: Text(
                    workout.currentWorkout!.type.displayName.toUpperCase(),
                  ),
                  actions: [
                    // Save button for authenticated users (hide for already saved timers)
                    if (canSave && workout.loadedFromWorkoutId == null)
                      IconButton(
                        icon: const Icon(Icons.save_outlined),
                        tooltip: 'Save timer',
                        onPressed: () => _openSaveModal(context, workout),
                      ),
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
                  actions: const [
                    AuthButton(),
                  ],
                ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: (workout.currentWorkout == null || workout.showInputOverride)
                      ? _buildInputView(context, workout)
                      : GestureDetector(
                          onHorizontalDragStart: (details) {
                            if (workout.isIdle) {
                              setState(() => _isSwipingToEdit = true);
                            }
                          },
                          onHorizontalDragUpdate: (details) {
                            if (workout.isIdle && _isSwipingToEdit) {
                              final screenWidth = MediaQuery.of(context).size.width;
                              setState(() {
                                // Track left swipes up to full screen width
                                _swipeOffset = (_swipeOffset + details.delta.dx).clamp(-screenWidth, 0.0);
                              });
                            }
                          },
                          onHorizontalDragEnd: (details) {
                            final screenWidth = MediaQuery.of(context).size.width;
                            final swipeThreshold = screenWidth * 0.3;
                            // Swipe left → edit timer (only when swiped >= 50%)
                            if (_swipeOffset.abs() >= swipeThreshold &&
                                workout.isIdle &&
                                widget.onNavigateToManualForEdit != null) {
                              // Animate off screen first
                              setState(() {
                                _swipeOffset = -screenWidth;
                                _isSwipingToEdit = false;
                              });
                              // Navigate after animation completes
                              Future.delayed(const Duration(milliseconds: 200), () {
                                if (mounted) {
                                  workout.setPendingEdit(workout.currentWorkout!);
                                  widget.onNavigateToManualForEdit!();
                                  // Reset for when returning
                                  setState(() => _swipeOffset = 0);
                                }
                              });
                            } else {
                              // Reset swipe state
                              setState(() {
                                _swipeOffset = 0;
                                _isSwipingToEdit = false;
                              });
                            }
                          },
                          onHorizontalDragCancel: () {
                            setState(() {
                              _swipeOffset = 0;
                              _isSwipingToEdit = false;
                            });
                          },
                          child: AnimatedContainer(
                            duration: _isSwipingToEdit ? Duration.zero : const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            transform: Matrix4.translationValues(_swipeOffset, 0, 0),
                            child: _buildTimerView(context, workout),
                          ),
                        ),
                ),
              ],
            ),
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

    final displayedSaved = _savedWorkouts.take(_maxSavedWorkoutsDisplay).toList();
    final savedOverflow = _savedWorkouts.length - _maxSavedWorkoutsDisplay;

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section label
            Text(
              'Create your timer.',
              style: AppTextStyles.h4,
            ),
            const SizedBox(height: 12),

            // Input field
            TextField(
              controller: _inputController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Describe your workout and we\'ll generate a custom timer for you.',
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

            // Create Timer buttons row
            Row(
              children: [
                // AI timer button (text input)
                Expanded(
                  child: ElevatedButton(
                    onPressed: (workout.isParsing || workout.isExtractingFromImage) ? null : () {
                      // Redirect to login if not authenticated
                      if (!auth.isAuthenticated) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                        return;
                      }
                      // Validate input
                      if (workout.workoutInput.trim().isEmpty) {
                        AppSnackBar.showError(context, 'Please enter a workout description');
                        return;
                      }
                      workout.parseWorkout();
                    },
                    child: (workout.isParsing || workout.isExtractingFromImage)
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text('Creating...'),
                            ],
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome),
                              SizedBox(width: 8),
                              Text('AI timer'),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Camera button
                GestureDetector(
                  onTap: (workout.isParsing || workout.isExtractingFromImage) ? null : () {
                    // Redirect to login if not authenticated
                    if (!auth.isAuthenticated) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                      return;
                    }
                    _showImagePickerModal(context, workout);
                  },
                  child: Container(
                    width: 64,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: (workout.isParsing || workout.isExtractingFromImage)
                          ? AppColors.textMuted
                          : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),

            // Saved timers section
            if (auth.isAuthenticated) ...[
              const SizedBox(height: 24),
              Text(
                'Saved templates',
                style: AppTextStyles.label,
              ),
              const SizedBox(height: 8),
              if (_savedWorkoutsLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Loading...',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                )
              else if (_savedWorkoutsError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _savedWorkoutsError!,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final w in displayedSaved)
                      LongPressDraggable<Workout>(
                        data: w,
                        onDragStarted: () {
                          setState(() => _isDraggingTimer = true);
                          widget.onDragStateChanged?.call(true, onDelete: _deleteWorkoutDirectly);
                        },
                        onDragEnd: (_) {
                          setState(() => _isDraggingTimer = false);
                          widget.onDragStateChanged?.call(false);
                        },
                        onDraggableCanceled: (_, __) {
                          setState(() => _isDraggingTimer = false);
                          widget.onDragStateChanged?.call(false);
                        },
                        feedback: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              border: Border.all(color: AppColors.primary),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              displayWorkoutName(w.name),
                              style: AppTextStyles.bodySmall,
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _SavedTimerChip(
                            workout: w,
                            onTap: () {},
                          ),
                        ),
                        child: _SavedTimerChip(
                          workout: w,
                          onTap: () {
                            workout.setWorkout(w, fromSavedWorkoutId: w.id);
                            workout.setShowInputOverride(false);
                          },
                        ),
                      ),
                  ],
                ),
              if (auth.isAuthenticated && savedOverflow > 0) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MyWorkoutsScreen(
                          onNavigateToTimer: () => Navigator.pop(context),
                        ),
                      ),
                    );
                    // Refresh list when returning from My Workouts (e.g. after delete or view)
                    if (mounted) {
                      final userId = context.read<AuthProvider>().user?.id;
                      if (userId != null) _loadSavedWorkouts(userId);
                    }
                  },
                  child: Text(
                    'View all ${_savedWorkouts.length} workouts',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    ),
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

  Widget _buildTimerView(BuildContext context, WorkoutProvider workout) {
    final currentWorkout = workout.currentWorkout!;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Main content
        SingleChildScrollView(
            controller: _scrollController,
            physics: _notesState != NotesState.closed
                ? const NeverScrollableScrollPhysics()
                : null,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              children: [
                // Swipe to edit hint (invisible when not idle to maintain layout)
                Opacity(
                  opacity: workout.isIdle ? 1.0 : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      children: [
                        Text(
                          'Swipe left to edit',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.textMuted,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

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
                        isAnimating: workout.isRunning || workout.isRest || workout.isCountdown,
                        centerWidget: _buildTimerCenterContent(workout, currentWorkout),
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
            mainAxisSize: _notesState != NotesState.closed ? MainAxisSize.max : MainAxisSize.min,
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
                      final isExitingToClose = _isNotesExiting && _notesState == NotesState.minimized;
                      return TweenAnimationBuilder<double>(
                        key: ValueKey('notes_panel_${isExitingToClose ? 'closing' : 'open'}'),
                        duration: const Duration(milliseconds: 300),
                        tween: Tween<double>(
                          begin: isExitingToClose ? 0.0 : 1.0,
                          end: isExitingToClose ? 1.0 : 0.0,
                        ),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          final screenHeight = MediaQuery.of(context).size.height;
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

  Widget? _buildTimerCenterContent(WorkoutProvider workout, Workout currentWorkout) {
    final showRoundCounter = workout.shouldShowRoundCounter;
    final showRounds = workout.totalRounds > 1 && currentWorkout.type != WorkoutType.workRest && !showRoundCounter;
    final isWorkRest = currentWorkout.type == WorkoutType.workRest;
    final showManualCounter = workout.shouldShowManualCounter;

    // If nothing extra to show, return null (default time display)
    if (!showRounds && !isWorkRest && !showManualCounter && !showRoundCounter) return null;

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
              top: workout.totalRestRounds > 0 ? timerSize * 0.18 : timerSize * 0.22,
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
          ]
          else if (showManualCounter) ...[
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
                  Icon(
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

  Widget _buildUnifiedNotesPanel(WorkoutProvider workout, String notes, bool isFull) {
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

class _SavedTimerChip extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;

  const _SavedTimerChip({
    required this.workout,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            displayWorkoutName(workout.name),
            style: AppTextStyles.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
