import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/workout.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/manual/timer_type_selector.dart';
import '../../widgets/manual/duration_stepper.dart';
import '../../widgets/manual/quick_select_chip.dart';
import '../../widgets/manual/number_stepper.dart';

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

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // Rest timer doesn't need countdown
  bool get _showCountdown => _selectedType != WorkoutType.restTimer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Timer'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Timer type selector
            TimerTypeSelector(
              selectedType: _selectedType,
              onTypeChanged: (type) {
                setState(() {
                  _selectedType = type;
                  _setDefaultsForType(type);
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

                    const SizedBox(height: 16),

                    // Start button
                    ElevatedButton(
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

                    const SizedBox(height: 16),
                  ],
                ),
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
                _workoutNotes.isEmpty ? 'Add note' : 'Edit note',
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
                Text('Timer Notes', style: AppTextStyles.h3),
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
        // Work section
        Text(
          'WORK (seconds)',
          style: AppTextStyles.labelSmall.copyWith(
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        NumberStepper(
          value: _workSeconds,
          minValue: 5,
          maxValue: 60,
          step: 5,
          suffix: 's',
          onChanged: (value) {
            setState(() => _workSeconds = value);
          },
        ),
        const SizedBox(height: 16),

        // Rest section
        Text(
          'REST (seconds)',
          style: AppTextStyles.labelSmall.copyWith(
            letterSpacing: 1.5,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        NumberStepper(
          value: _restSeconds,
          minValue: 5,
          maxValue: 60,
          step: 5,
          suffix: 's',
          onChanged: (value) {
            setState(() => _restSeconds = value);
          },
        ),
        const SizedBox(height: 16),

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
          maxValue: 20,
          onChanged: (value) {
            setState(() => _rounds = value);
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
        // Work Duration section
        Text(
          'WORK DURATION',
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

        // Rest Duration section
        Text(
          'REST DURATION',
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
        const SizedBox(height: 16),

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
          maxValue: 99,
          onChanged: (value) {
            setState(() => _rounds = value);
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

  void _startTimer() {
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

    // Navigate back to timer tab
    widget.onNavigateToTimer?.call();
  }
}
