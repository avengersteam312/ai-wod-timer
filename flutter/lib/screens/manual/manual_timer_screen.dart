import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/workout.dart';
import '../../models/movement.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_button.dart';
import '../../utils/workout_name.dart';
import '../../widgets/manual/timer_type_selector.dart';
import '../../widgets/manual/duration_stepper.dart';
import '../../widgets/manual/quick_select_chip.dart';
import '../../widgets/manual/number_stepper.dart';
import '../../widgets/save_template_modal.dart';

class ManualTimerScreen extends StatefulWidget {
  final VoidCallback? onNavigateToTimer;

  const ManualTimerScreen({super.key, this.onNavigateToTimer});

  @override
  State<ManualTimerScreen> createState() => _ManualTimerScreenState();
}

class _ManualTimerScreenState extends State<ManualTimerScreen> {
  WorkoutType _selectedType = WorkoutType.restTimer;

  // Timer configurations
  int _totalSeconds = 0;
  int _workSeconds = 20;
  int _restSeconds = 10;
  int _rounds = 8;
  int _intervalSeconds = 60;

  // Work/Rest fixed rest option
  bool _useFixedRest = false;

  // Countdown (preparation time)
  int _countdownSeconds = 5;

  // Notes
  String _workoutNotes = '';
  final _notesController = TextEditingController();

  // Editing from AI timer
  bool _isEditingFromTimer = false;
  bool _isFromAiTimer = false;
  List<Movement> _pendingMovements = [];
  bool _consumingPendingEdit = false;
  WorkoutProvider? _workoutProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<WorkoutProvider>();
    if (_workoutProvider != provider) {
      _workoutProvider?.removeListener(_onWorkoutChanged);
      _workoutProvider = provider;
      _workoutProvider!.addListener(_onWorkoutChanged);
    }
  }

  void _onWorkoutChanged() {
    if (!mounted) return;
    if (_workoutProvider?.currentWorkout == null && _isEditingFromTimer) {
      setState(() {
        _isEditingFromTimer = false;
        _isFromAiTimer = false;
        _pendingMovements = [];
        _selectedType = WorkoutType.restTimer;
        _setDefaultsForType(WorkoutType.restTimer);
      });
    }
  }

  void _resetForm() {
    setState(() {
      _isEditingFromTimer = false;
      _isFromAiTimer = false;
      _pendingMovements = [];
      _selectedType = WorkoutType.restTimer;
      _workoutNotes = '';
      _setDefaultsForType(WorkoutType.restTimer);
    });
  }

  @override
  void dispose() {
    _workoutProvider?.removeListener(_onWorkoutChanged);
    _notesController.dispose();
    super.dispose();
  }

  void _tryConsumePendingEdit() {
    final provider = context.read<WorkoutProvider>();
    final pending = provider.pendingEditWorkout;
    if (pending == null) return;

    provider.consumePendingEdit();

    final config = pending.timerConfig;
    final workIntervals = config.intervals.where((i) => i.isWork).toList();
    final restIntervals = config.intervals.where((i) => i.isRest).toList();
    final type = _mapToManualType(pending.type);

    setState(() {
      _selectedType = type;
      _rounds = config.workRounds > 0 ? config.workRounds : (config.rounds ?? 1);
      _workSeconds = workIntervals.isNotEmpty ? workIntervals.first.duration : (config.workSeconds ?? 20);
      _restSeconds = restIntervals.isNotEmpty ? restIntervals.first.duration : (config.restSeconds ?? 10);
      _totalSeconds = config.totalDuration > 0 ? config.totalDuration : (config.totalSeconds ?? 600);
      _intervalSeconds = workIntervals.isNotEmpty ? workIntervals.first.duration : (config.intervalSeconds ?? 60);
      _pendingMovements = List.from(pending.movements);
      // Use rawInput (extracted text from image) if notes is empty
      _workoutNotes = pending.notes?.isNotEmpty == true
          ? pending.notes!
          : (pending.rawInput ?? '');
      _isEditingFromTimer = true;
      _isFromAiTimer = pending.rawInput?.isNotEmpty == true;
    });
  }

  WorkoutType _mapToManualType(WorkoutType type) {
    switch (type) {
      case WorkoutType.amrap:
      case WorkoutType.emom:
      case WorkoutType.tabata:
      case WorkoutType.forTime:
      case WorkoutType.stopwatch:
      case WorkoutType.workRest:
      case WorkoutType.restTimer:
      case WorkoutType.customInterval:
        return type;
      default:
        return WorkoutType.customInterval;
    }
  }

  // Rest timer doesn't need countdown
  bool get _showCountdown => _selectedType != WorkoutType.restTimer;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Detect pending edit from timer screen and consume it
    final hasPendingEdit = context.select<WorkoutProvider, bool>(
      (w) => w.pendingEditWorkout != null,
    );
    if (hasPendingEdit && !_consumingPendingEdit) {
      _consumingPendingEdit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _consumingPendingEdit = false;
        if (mounted) _tryConsumePendingEdit();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Timer'),
        actions: [
          if (auth.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save timer',
              onPressed: _showSaveModal,
            ),
          const AuthButton(),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 12),

                  // Timer type selector
                  TimerTypeSelector(
                    selectedType: _selectedType,
                    onTypeChanged: (type) {
                      setState(() {
                        _selectedType = type;
                        _setDefaultsForType(type);
                        _isEditingFromTimer = false;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Configuration inputs
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Editing banner (only show for AI-created timers)
                          if (_isEditingFromTimer && _isFromAiTimer) ...[
                            _buildEditingBanner(),
                            const SizedBox(height: 16),
                          ],

                          // Type description with countdown selector
                          _buildTypeHeader(),
                          const SizedBox(height: 16),

                          // Dynamic inputs based on type
                          _buildConfigInputs(),

                          // Countdown input (not for rest timer)
                          if (_showCountdown) ...[
                            const SizedBox(height: 16),
                            _buildCountdownInput(),
                          ],

                          const SizedBox(height: 16),

                          // Add note button (not for rest timer)
                          if (_selectedType != WorkoutType.restTimer)
                            _buildNotesButton(),

                          // Extra space for button
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Start button - fixed at bottom with transparent background
              Positioned(
                left: 24,
                right: 24,
                bottom: 16,
                child: ElevatedButton(
                  onPressed: _startTimer,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow),
                      SizedBox(width: 8),
                      Text('Start Timer'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditingBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.tune, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Text(
            'Editing AI timer — adjust and start',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryLight),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MOVEMENTS',
          style: AppTextStyles.labelSmall.copyWith(
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        ..._pendingMovements.asMap().entries.map((entry) {
          final index = entry.key;
          final movement = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    movement.displayText,
                    style: AppTextStyles.body,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Edit movement',
                  onPressed: () => _showMovementEditSheet(index, movement),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _showMovementEditSheet(int index, Movement movement) {
    final nameController = TextEditingController(text: movement.name);
    final repsController = TextEditingController(text: movement.reps?.toString() ?? '');
    final weightController = TextEditingController(text: movement.weight?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Edit Movement', style: AppTextStyles.h3),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Name', style: AppTextStyles.label),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: 'Movement name'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reps', style: AppTextStyles.label),
                      const SizedBox(height: 8),
                      TextField(
                        controller: repsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'e.g. 10'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weight (${movement.weightUnit ?? 'lbs'})', style: AppTextStyles.label),
                      const SizedBox(height: 8),
                      TextField(
                        controller: weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(hintText: 'optional'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final updated = movement.copyWith(
                    name: nameController.text.trim().isNotEmpty ? nameController.text.trim() : movement.name,
                    reps: int.tryParse(repsController.text) ?? movement.reps,
                    weight: double.tryParse(weightController.text) ?? movement.weight,
                  );
                  setState(() {
                    _pendingMovements[index] = updated;
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setDefaultsForType(WorkoutType type) {
    // Reset fixed rest option
    _useFixedRest = false;

    switch (type) {
      case WorkoutType.stopwatch:
        break;
      case WorkoutType.amrap:
        _totalSeconds = 10 * 60; // 10 minutes default
        break;
      case WorkoutType.emom:
        _rounds = 10; // 10 rounds default
        _intervalSeconds = 60; // 1 minute intervals
        break;
      case WorkoutType.tabata:
        _workSeconds = 20;
        _restSeconds = 10;
        _rounds = 8;
        break;
      case WorkoutType.workRest:
        _rounds = 5;
        _restSeconds = 30; // Default fixed rest if enabled
        break;
      case WorkoutType.restTimer:
        _totalSeconds = 60;
        break;
      case WorkoutType.forTime:
        _totalSeconds = 0; // No cap by default
        break;
      case WorkoutType.customInterval:
        _workSeconds = 30;
        _restSeconds = 10;
        _rounds = 8;
        break;
      default:
        break;
    }
  }

  Widget _buildTypeHeader() {
    String description;
    switch (_selectedType) {
      case WorkoutType.stopwatch:
        description = 'Count up from zero';
        break;
      case WorkoutType.amrap:
        description = 'As many rounds as possible';
        break;
      case WorkoutType.emom:
        description = 'Every minute on the minute';
        break;
      case WorkoutType.tabata:
        description = 'High-intensity interval training';
        break;
      case WorkoutType.workRest:
        description = 'Rest equals your work time';
        break;
      case WorkoutType.restTimer:
        description = 'Quick rest between sets';
        break;
      case WorkoutType.forTime:
        description = 'Beat the clock';
        break;
      case WorkoutType.customInterval:
        description = 'Custom work/rest periods';
        break;
      default:
        description = '';
    }

    return Center(
      child: Text(
        description,
        style: AppTextStyles.body.copyWith(
          color: AppColors.textSecondary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Countdown input widget - same style as other inputs
  Widget _buildCountdownInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COUNTDOWN',
          style: AppTextStyles.labelSmall.copyWith(
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        NumberStepper(
          value: _countdownSeconds,
          minValue: 0,
          maxValue: 30,
          onChanged: (value) {
            setState(() => _countdownSeconds = value);
                      },
        ),
      ],
    );
  }

  Widget _buildNotesButton() {
    return GestureDetector(
      onTap: _showNotesSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.edit_note,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _workoutNotes.isEmpty ? 'Add notes' : 'Edit notes',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  void _showNotesSheet() {
    _notesController.text = _workoutNotes;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Notes', style: AppTextStyles.h3),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 5,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Add workout details, movements, goals...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _workoutNotes = _notesController.text;
                  });
                                    Navigator.pop(ctx);
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigInputs() {
    switch (_selectedType) {
      case WorkoutType.stopwatch:
        return _buildStopwatchInputs();
      case WorkoutType.amrap:
        return _buildAmrapInputs();
      case WorkoutType.emom:
        return _buildEmomInputs();
      case WorkoutType.tabata:
        return _buildTabataInputs();
      case WorkoutType.workRest:
        return _buildWorkRestInputs();
      case WorkoutType.restTimer:
        return _buildRestTimerInputs();
      case WorkoutType.forTime:
        return _buildForTimeInputs();
      case WorkoutType.customInterval:
        return _buildCustomIntervalInputs();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStopwatchInputs() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                Icons.timer,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'No configuration needed',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Timer will count up from 00:00',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmrapInputs() {
    return _buildTimerWithDurationInput(
      label: 'TIME CAP',
      totalSeconds: _totalSeconds,
      minSeconds: 60,
      maxSeconds: 3600,
      step: 60,
      onChanged: (value) {
        setState(() => _totalSeconds = value);
              },
    );
  }

  Widget _buildEmomInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rounds section
        Text(
          'ROUNDS',
          style: AppTextStyles.labelSmall.copyWith(
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        NumberStepper(
          value: _rounds,
          minValue: 1,
          maxValue: 30,
          onChanged: (value) {
            setState(() => _rounds = value);
                      },
        ),
        const SizedBox(height: 16),

        // Interval section
        Text(
          'INTERVAL',
          style: AppTextStyles.labelSmall.copyWith(
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        DurationStepper(
          totalSeconds: _intervalSeconds,
          minSeconds: 30,
          maxSeconds: 300, // 5 minutes max
          step: 30,
          onChanged: (value) {
            setState(() => _intervalSeconds = value);
                      },
        ),
      ],
    );
  }

  Widget _buildTabataInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rounds section (first)
        Text(
          'ROUNDS',
          style: AppTextStyles.labelSmall.copyWith(
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        NumberStepper(
          value: _rounds,
          minValue: 1,
          maxValue: 20,
          onChanged: (value) {
            setState(() => _rounds = value);
          },
        ),
        const SizedBox(height: 16),

        // Work section
        Text(
          'WORK',
          style: AppTextStyles.labelSmall.copyWith(
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        DurationStepper(
          totalSeconds: _workSeconds,
          minSeconds: 5,
          maxSeconds: 300, // 5 minutes max
          step: 5,
          onChanged: (value) {
            setState(() => _workSeconds = value);
          },
        ),
        const SizedBox(height: 16),

        // Rest section
        Text(
          'REST',
          style: AppTextStyles.labelSmall.copyWith(
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        DurationStepper(
          totalSeconds: _restSeconds,
          minSeconds: 5,
          maxSeconds: 300, // 5 minutes max
          step: 5,
          onChanged: (value) {
            setState(() => _restSeconds = value);
          },
        ),
      ],
    );
  }

  Widget _buildWorkRestInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rounds section
        Text(
          'ROUNDS',
          style: AppTextStyles.labelSmall.copyWith(
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        NumberStepper(
          value: _rounds,
          minValue: 1,
          maxValue: 50,
          onChanged: (value) {
            setState(() => _rounds = value);
                      },
        ),
        const SizedBox(height: 24),
        // Fixed rest toggle
        Row(
          children: [
            Text(
              'FIXED REST',
              style: AppTextStyles.labelSmall.copyWith(
                letterSpacing: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(optional)',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const Spacer(),
            Switch(
              value: _useFixedRest,
              onChanged: (value) {
                setState(() {
                  _useFixedRest = value;
                  if (value && _restSeconds == 0) {
                    _restSeconds = 30;
                  }
                });
                              },
            ),
          ],
        ),
        if (_useFixedRest) ...[
          const SizedBox(height: 8),
          DurationStepper(
            totalSeconds: _restSeconds,
            minSeconds: 5,
            maxSeconds: 300,
            step: 5,
            onChanged: (value) {
              setState(() => _restSeconds = value);
                          },
          ),
        ],
      ],
    );
  }

  Widget _buildCustomIntervalInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rounds section (first, like other timer types)
        Text(
          'ROUNDS',
          style: AppTextStyles.labelSmall.copyWith(
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        NumberStepper(
          value: _rounds,
          minValue: 1,
          maxValue: 99,
          onChanged: (value) {
            setState(() => _rounds = value);
          },
        ),
        const SizedBox(height: 16),

        // Work section
        Text(
          'WORK',
          style: AppTextStyles.labelSmall.copyWith(
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        DurationStepper(
          totalSeconds: _workSeconds,
          minSeconds: 5,
          maxSeconds: 600,
          step: 5,
          onChanged: (value) {
            setState(() => _workSeconds = value);
          },
        ),
        const SizedBox(height: 16),

        // Rest section
        Text(
          'REST',
          style: AppTextStyles.labelSmall.copyWith(
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        DurationStepper(
          totalSeconds: _restSeconds,
          minSeconds: 0,
          maxSeconds: 600,
          step: 5,
          onChanged: (value) {
            setState(() => _restSeconds = value);
          },
        ),
      ],
    );
  }

  Widget _buildRestTimerInputs() {
    // Quick select options - tapping starts timer immediately
    const quickSelectOptions = [
      QuickSelectOption(label: '30s', value: 30),
      QuickSelectOption(label: '1 min', value: 60),
      QuickSelectOption(label: '2 min', value: 120),
      QuickSelectOption(label: '3 min', value: 180),
      QuickSelectOption(label: '5 min', value: 300),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Select section
        Text(
          'QUICK SELECT',
          style: AppTextStyles.labelSmall.copyWith(
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        QuickSelectGrid(
          options: quickSelectOptions,
          selectedValue: null, // No selection state - tapping starts immediately
          onSelected: (seconds) {
            // Start timer immediately with selected duration
            _startRestTimer(seconds);
          },
        ),
        const SizedBox(height: 20),

        // Custom Duration section
        Text(
          'CUSTOM DURATION',
          style: AppTextStyles.labelSmall.copyWith(
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        DurationStepper(
          totalSeconds: _totalSeconds,
          minSeconds: 15,
          maxSeconds: 600,
          step: 15,
          onChanged: (value) {
            setState(() => _totalSeconds = value);
          },
        ),
      ],
    );
  }

  /// Start rest timer with specified duration
  void _startRestTimer(int seconds) {
    // Dismiss keyboard first
    FocusScope.of(context).unfocus();

    final workout = context.read<WorkoutProvider>();

    workout.setManualTimer(
      type: WorkoutType.restTimer,
      totalSeconds: seconds,
      hasCountdown: false,
    );

    // Start the timer immediately and navigate
    workout.startTimer();
    widget.onNavigateToTimer?.call();
  }

  Widget _buildForTimeInputs() {
    return _buildTimerWithDurationInput(
      label: 'TIME CAP (optional)',
      totalSeconds: _totalSeconds,
      minSeconds: 0,
      maxSeconds: 3600,
      step: 60,
      onChanged: (value) {
        setState(() => _totalSeconds = value);
              },
    );
  }

  /// Reusable widget for timer types with duration input (AMRAP, For Time, etc.)
  Widget _buildTimerWithDurationInput({
    required String label,
    required int totalSeconds,
    required int minSeconds,
    required int maxSeconds,
    required int step,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        DurationStepper(
          totalSeconds: totalSeconds,
          minSeconds: minSeconds,
          maxSeconds: maxSeconds,
          step: step,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _showSaveModal() async {
    final workoutProvider = context.read<WorkoutProvider>();
    final userId = context.read<AuthProvider>().user?.id;

    await SaveTemplateModal.show(
      context: context,
      defaultName: defaultManualWorkoutName(_selectedType),
      onCheckNameTaken: userId != null
          ? (name) => workoutProvider.isWorkoutNameTaken(userId, name)
          : null,
      onSave: (name) async {
        int? totalSeconds;
        int? workSeconds;
        int? restSeconds;
        int? rounds;
        int? intervalSeconds;

        switch (_selectedType) {
          case WorkoutType.stopwatch:
            break;
          case WorkoutType.amrap:
          case WorkoutType.forTime:
            totalSeconds = _totalSeconds;
            break;
          case WorkoutType.emom:
            rounds = _rounds;
            intervalSeconds = _intervalSeconds;
            totalSeconds = _rounds * _intervalSeconds;
            break;
          case WorkoutType.tabata:
            workSeconds = _workSeconds;
            restSeconds = _restSeconds;
            rounds = _rounds;
            totalSeconds = (_workSeconds + _restSeconds) * _rounds;
            break;
          case WorkoutType.workRest:
            rounds = _rounds;
            if (_useFixedRest) restSeconds = _restSeconds;
            break;
          case WorkoutType.restTimer:
            totalSeconds = _totalSeconds;
            break;
          case WorkoutType.customInterval:
            workSeconds = _workSeconds;
            restSeconds = _restSeconds;
            rounds = _rounds;
            totalSeconds = (_workSeconds + _restSeconds) * _rounds;
            break;
          default:
            break;
        }

        final workout = workoutProvider.buildManualWorkoutForSave(
          type: _selectedType,
          totalSeconds: totalSeconds,
          workSeconds: workSeconds,
          restSeconds: restSeconds,
          rounds: rounds,
          intervalSeconds: intervalSeconds,
          hasCountdown: _showCountdown,
          countdownSeconds: _countdownSeconds,
          notes: _workoutNotes.isNotEmpty ? _workoutNotes : null,
          name: name,
        );

        await workoutProvider.saveWorkout(workout);
        return true;
      },
      onSaveSuccess: () {
        // Success message shown in modal
      },
    );
  }

  void _startTimer() {
    // Dismiss keyboard first to commit any pending edits from steppers
    FocusScope.of(context).unfocus();

    // Wait for state updates to propagate after focus change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _doStartTimer();
    });
  }

  void _doStartTimer() {
    final workout = context.read<WorkoutProvider>();

    int? totalSeconds;
    int? workSeconds;
    int? restSeconds;
    int? rounds;
    int? intervalSeconds;

    switch (_selectedType) {
      case WorkoutType.stopwatch:
        // No config needed
        break;
      case WorkoutType.amrap:
      case WorkoutType.forTime:
        totalSeconds = _totalSeconds;
        break;
      case WorkoutType.emom:
        rounds = _rounds;
        intervalSeconds = _intervalSeconds;
        totalSeconds = _rounds * _intervalSeconds;
        break;
      case WorkoutType.tabata:
        workSeconds = _workSeconds;
        restSeconds = _restSeconds;
        rounds = _rounds;
        totalSeconds = (_workSeconds + _restSeconds) * _rounds;
        break;
      case WorkoutType.workRest:
        rounds = _rounds;
        // Only set restSeconds if fixed rest is enabled
        if (_useFixedRest) {
          restSeconds = _restSeconds;
        }
        break;
      case WorkoutType.restTimer:
        totalSeconds = _totalSeconds;
        // Rest timer starts immediately, no countdown needed
        workout.setManualTimer(
          type: _selectedType,
          totalSeconds: totalSeconds,
          hasCountdown: false,
        );
        workout.startTimer();
        widget.onNavigateToTimer?.call();
        return;
      case WorkoutType.customInterval:
        workSeconds = _workSeconds;
        restSeconds = _restSeconds;
        rounds = _rounds;
        totalSeconds = (_workSeconds + _restSeconds) * _rounds;
        break;
      default:
        break;
    }

    workout.setManualTimer(
      type: _selectedType,
      totalSeconds: totalSeconds,
      workSeconds: workSeconds,
      restSeconds: restSeconds,
      rounds: rounds,
      intervalSeconds: intervalSeconds,
      hasCountdown: _showCountdown,
      countdownSeconds: _countdownSeconds,
      notes: _workoutNotes.isNotEmpty ? _workoutNotes : null,
    );

    if (_isEditingFromTimer && _pendingMovements.isNotEmpty) {
      workout.updateCurrentWorkoutMovements(_pendingMovements);
    }
    _isEditingFromTimer = false;

    // Navigate back to timer tab
    widget.onNavigateToTimer?.call();
  }
}
