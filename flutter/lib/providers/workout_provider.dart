import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/workout.dart';
import '../models/movement.dart';
import '../models/workout_session.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../services/haptics_service.dart';
import '../services/offline_storage_service.dart';
import 'auth_provider.dart';

enum TimerState {
  idle,
  countdown,
  running,
  paused,
  rest,
  completed,
}

enum TimerPhase {
  countdown,
  work,
  rest,
}

class WorkoutProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final AudioService _audioService = AudioService();
  final HapticsService _hapticsService = HapticsService();
  final OfflineStorageService _storageService = OfflineStorageService();
  final Uuid _uuid = const Uuid();

  // Auth reference
  AuthProvider? _authProvider;

  // Workout state
  Workout? _currentWorkout;
  String _workoutInput = '';
  bool _isParsing = false;
  String? _parseError;

  // Timer state
  TimerState _timerState = TimerState.idle;
  TimerPhase _timerPhase = TimerPhase.countdown;
  int _elapsedSeconds = 0;
  int _remainingSeconds = 0;
  int _currentRound = 1;
  int _currentMovementIndex = 0;
  Timer? _timer;

  // Interval-based timer state
  int _currentIntervalIndex = 0;
  int _intervalElapsedSeconds = 0;

  // Work/Rest total time tracking
  int _totalWorkSeconds = 0;
  int _totalRestSeconds = 0;

  // Final round counts (preserved when completing early)
  int? _finalWorkRound;
  int? _finalRestRound;

  // Manual counter (for counting rounds, reps, etc.)
  int _counter = 0;

  // Session tracking
  WorkoutSession? _currentSession;
  DateTime? _sessionStartTime;

  // UI state - show AI input view while timer is running
  bool _showInputOverride = false;

  // Getters
  Workout? get currentWorkout => _currentWorkout;
  String get workoutInput => _workoutInput;
  bool get isParsing => _isParsing;
  String? get parseError => _parseError;

  TimerState get timerState => _timerState;
  TimerPhase get timerPhase => _timerPhase;
  int get elapsedSeconds => _elapsedSeconds;
  int get remainingSeconds => _remainingSeconds;
  int get currentRound => _currentRound;
  int get currentMovementIndex => _currentMovementIndex;

  bool get isRunning => _timerState == TimerState.running;
  bool get isPaused => _timerState == TimerState.paused;
  bool get isCountdown => _timerState == TimerState.countdown;
  bool get isCompleted => _timerState == TimerState.completed;
  bool get isIdle => _timerState == TimerState.idle;
  bool get isRest => _timerState == TimerState.rest;

  // UI state for showing input while timer runs
  bool get showInputOverride => _showInputOverride;

  void setShowInputOverride(bool value) {
    _showInputOverride = value;
    notifyListeners();
  }

  void toggleInputOverride() {
    _showInputOverride = !_showInputOverride;
    notifyListeners();
  }

  Movement? get currentMovement {
    if (_currentWorkout == null || _currentWorkout!.movements.isEmpty) {
      return null;
    }
    if (_currentMovementIndex >= _currentWorkout!.movements.length) {
      return null;
    }
    return _currentWorkout!.movements[_currentMovementIndex];
  }

  Movement? get nextMovement {
    if (_currentWorkout == null || _currentWorkout!.movements.isEmpty) {
      return null;
    }
    final nextIndex = _currentMovementIndex + 1;
    if (nextIndex >= _currentWorkout!.movements.length) {
      return null;
    }
    return _currentWorkout!.movements[nextIndex];
  }

  int get totalRounds {
    // Use workRounds from intervals if available
    final workRounds = _currentWorkout?.timerConfig.workRounds ?? 0;
    if (workRounds > 0) return workRounds;
    // Fallback to rounds config
    return _currentWorkout?.timerConfig.rounds ?? 1;
  }

  // Work/Rest total time getters
  int get totalWorkSeconds => _totalWorkSeconds;
  int get totalRestSeconds => _totalRestSeconds;

  String get formattedTotalWorkTime {
    final minutes = _totalWorkSeconds ~/ 60;
    final seconds = _totalWorkSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedTotalRestTime {
    final minutes = _totalRestSeconds ~/ 60;
    final seconds = _totalRestSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Interval-based getters
  int get currentIntervalIndex => _currentIntervalIndex;
  int get intervalElapsedSeconds => _intervalElapsedSeconds;

  List<TimerInterval> get intervals =>
      _currentWorkout?.timerConfig.intervals ?? [];

  TimerInterval? get currentInterval {
    if (intervals.isEmpty || _currentIntervalIndex >= intervals.length) {
      return null;
    }
    return intervals[_currentIntervalIndex];
  }

  TimerInterval? get nextInterval {
    final nextIndex = _currentIntervalIndex + 1;
    if (intervals.isEmpty || nextIndex >= intervals.length) {
      return null;
    }
    return intervals[nextIndex];
  }

  /// Returns true if the next interval is a rest interval
  bool get isNextRest => nextInterval?.isRest ?? false;

  /// Total number of work intervals
  int get totalWorkRounds {
    return intervals.where((i) => i.isWork).length;
  }

  /// Total number of rest intervals
  int get totalRestRounds {
    return intervals.where((i) => i.isRest).length;
  }

  /// Current work round (1-indexed, 0 if not started or in countdown)
  int get currentWorkRound {
    if (_timerState == TimerState.idle || _timerState == TimerState.countdown) return 0;
    if (_timerState == TimerState.completed) return _finalWorkRound ?? totalWorkRounds;

    int workCount = 0;
    for (int i = 0; i < _currentIntervalIndex; i++) {
      if (intervals[i].isWork) workCount++;
    }
    // Add 1 if currently in a work interval
    if (currentInterval?.isWork == true) workCount++;
    return workCount;
  }

  /// Current rest round (1-indexed, 0 if not started or in countdown)
  int get currentRestRound {
    if (_timerState == TimerState.idle || _timerState == TimerState.countdown) return 0;
    if (_timerState == TimerState.completed) return _finalRestRound ?? totalRestRounds;

    int restCount = 0;
    for (int i = 0; i < _currentIntervalIndex; i++) {
      if (intervals[i].isRest) restCount++;
    }
    // Add 1 if currently in a rest interval
    if (currentInterval?.isRest == true) restCount++;
    return restCount;
  }

  /// Whether this timer should show the round counter block
  bool get shouldShowRoundCounter {
    // Show for interval-based timers with both work and rest
    return totalWorkRounds > 0 && totalRestRounds > 0;
  }

  // Manual counter getters and methods
  int get counter => _counter;

  void incrementCounter() {
    _counter++;
    notifyListeners();
  }

  void decrementCounter() {
    if (_counter > 0) {
      _counter--;
      notifyListeners();
    }
  }

  void resetCounter() {
    _counter = 0;
    notifyListeners();
  }

  /// Whether this timer should show the manual counter
  bool get shouldShowManualCounter {
    final type = _currentWorkout?.type;
    if (type == null) return false;
    // Show for AMRAP, For Time, Stopwatch (single work interval timers)
    return type == WorkoutType.amrap ||
        type == WorkoutType.forTime ||
        type == WorkoutType.stopwatch;
  }

  /// Returns the effective duration of the current interval
  /// (considers dynamic rest duration for Work/Rest timer)
  int get _effectiveIntervalDuration {
    final interval = currentInterval;
    if (interval == null) return 0;

    // For Work/Rest timer rest intervals
    if (_currentWorkout?.type == WorkoutType.workRest && interval.isRest) {
      // Use fixed rest from config if set, otherwise use dynamic duration
      final fixedRest = _currentWorkout?.timerConfig.restSeconds;
      if (fixedRest != null && fixedRest > 0) {
        return fixedRest;
      }
      // Use dynamic duration (matches previous work time)
      if (_dynamicRestDuration > 0) {
        return _dynamicRestDuration;
      }
    }

    return interval.duration;
  }

  /// Returns remaining seconds in current interval
  int get intervalRemainingSeconds {
    final interval = currentInterval;
    if (interval == null || interval.isStopwatch) return 0;
    final duration = _effectiveIntervalDuration;
    if (duration == 0) return 0;
    return duration - _intervalElapsedSeconds;
  }

  double get progress {
    if (_currentWorkout == null) return 0;

    // No progress during countdown
    if (_timerState == TimerState.countdown) {
      return 0;
    }

    // Interval-based progress
    final interval = currentInterval;
    final effectiveDuration = _effectiveIntervalDuration;
    if (interval == null || effectiveDuration == 0) {
      // Stopwatch mode - no progress
      return 0;
    }

    // Progress within current interval (0 to 1)
    // Add 1 second offset only after timer has started (not on initial state)
    final offset = _intervalElapsedSeconds > 0 ? 1 : 0;
    final adjustedElapsed = (_intervalElapsedSeconds + offset).clamp(0, effectiveDuration);
    return adjustedElapsed / effectiveDuration;
  }

  String get formattedTime {
    // Use interval-based time if available
    final interval = currentInterval;
    final effectiveDuration = _effectiveIntervalDuration;
    int displaySeconds;

    if (_timerState == TimerState.idle) {
      // Show countdown seconds when timer not started
      final countdown = _currentWorkout?.timerConfig.countdownSeconds ?? 5;
      displaySeconds = countdown;
    } else if (_timerState == TimerState.countdown || _pausedDuringCountdown) {
      // Show countdown remaining (even when paused)
      displaySeconds = _remainingSeconds;
    } else if (interval != null && effectiveDuration > 0) {
      // Show remaining time in current interval
      displaySeconds = effectiveDuration - _intervalElapsedSeconds;
    } else {
      // Stopwatch mode - show elapsed
      displaySeconds = _intervalElapsedSeconds;
    }

    final minutes = displaySeconds.abs() ~/ 60;
    final seconds = displaySeconds.abs() % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedElapsedTime {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void updateAuth(AuthProvider auth) {
    _authProvider = auth;
  }

  // Parse workout input using AI
  Future<void> parseWorkout() async {
    if (_workoutInput.trim().isEmpty) {
      _parseError = 'Please enter a workout description';
      notifyListeners();
      return;
    }

    try {
      _isParsing = true;
      _parseError = null;
      notifyListeners();

      final result = await _apiService.parseWorkout(_workoutInput);

      // Convert API response to Workout model
      _currentWorkout = _createWorkoutFromResponse(result);
      _isParsing = false;
      notifyListeners();
    } catch (e) {
      _parseError = 'Failed to parse workout. Please try again.';
      _isParsing = false;
      notifyListeners();
    }
  }

  Workout _createWorkoutFromResponse(Map<String, dynamic> response) {
    final userId = _authProvider?.user?.id ?? 'anonymous';

    // Parse movements
    final movementsList = (response['movements'] as List<dynamic>?)
            ?.map((m) {
              final map = m as Map<String, dynamic>;
              // Handle reps as int or string (AI may return either)
              int? reps;
              final repsValue = map['reps'];
              if (repsValue is int) {
                reps = repsValue;
              } else if (repsValue is String) {
                reps = int.tryParse(repsValue);
              }
              // Handle weight as num or string (AI returns string like "225#")
              double? weight;
              String? weightUnit;
              final weightValue = map['weight'];
              if (weightValue is num) {
                weight = weightValue.toDouble();
              } else if (weightValue is String) {
                // Extract numeric part from strings like "225#" or "95 lbs"
                final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(weightValue);
                if (match != null) {
                  weight = double.tryParse(match.group(1)!);
                }
                // Extract unit from weight string if not separately provided
                if (map['weight_unit'] == null) {
                  if (weightValue.contains('#') || weightValue.contains('lb')) {
                    weightUnit = 'lbs';
                  } else if (weightValue.contains('kg')) {
                    weightUnit = 'kg';
                  }
                }
              }
              // Handle duration as int or string
              int? durationSeconds;
              final durValue = map['duration'] ?? map['duration_seconds'];
              if (durValue is int) {
                durationSeconds = durValue;
              } else if (durValue is String) {
                durationSeconds = int.tryParse(durValue);
              }
              return Movement(
                id: _uuid.v4(),
                name: map['name'] as String? ?? '',
                reps: reps,
                durationSeconds: durationSeconds,
                unit: map['unit'] as String?,
                weight: weight,
                weightUnit: weightUnit ?? map['weight_unit'] as String?,
                notes: map['notes'] as String?,
              );
            })
            .toList() ??
        [];

    // Parse timer config using fromJson to properly parse intervals
    final timerConfigMap =
        response['timer_config'] as Map<String, dynamic>? ?? {};

    return Workout(
      id: _uuid.v4(),
      userId: userId,
      name: response['name'] as String? ?? 'Workout',
      rawInput: _workoutInput,
      type: WorkoutTypeExtension.fromString(
        response['workout_type'] as String? ?? response['type'] as String? ?? 'custom',
      ),
      timerConfig: TimerConfig.fromJson(timerConfigMap),
      movements: movementsList,
      createdAt: DateTime.now(),
    );
  }

  void setWorkoutInput(String input) {
    _workoutInput = input;
    notifyListeners();
  }

  void setWorkout(Workout workout) {
    _currentWorkout = workout;
    _workoutInput = workout.rawInput ?? '';
    resetTimer();
    notifyListeners();
  }

  // Timer controls
  void startTimer() {
    if (_currentWorkout == null) return;

    final config = _currentWorkout!.timerConfig;

    if (_timerState == TimerState.idle) {
      // Create session
      _startSession();

      // Skip countdown if hasCountdown is false
      if (!config.hasCountdown) {
        _startWorkPhase();
      } else {
        // Start with countdown phase
        _timerState = TimerState.countdown;
        _remainingSeconds = config.countdownSeconds > 0 ? config.countdownSeconds : 5;
        _startCountdownTimer();
      }
    } else if (_timerState == TimerState.paused) {
      _resumeTimer();
    }

    notifyListeners();
  }

  void _startCountdownTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingSeconds--;

      // Play countdown sounds
      if (_remainingSeconds <= 3 && _remainingSeconds >= 0) {
        _audioService.playCountdown(_remainingSeconds);
        _hapticsService.countdown();
      }

      if (_remainingSeconds <= 0) {
        timer.cancel();
        _startWorkPhase();
      }

      notifyListeners();
    });
  }

  void _startWorkPhase() {
    _sessionStartTime = DateTime.now();

    // Initialize interval state
    _currentIntervalIndex = 0;
    _intervalElapsedSeconds = 0;

    final interval = currentInterval;
    if (interval != null) {
      _timerState = interval.isWork ? TimerState.running : TimerState.rest;
      _timerPhase = interval.isWork ? TimerPhase.work : TimerPhase.rest;
    } else {
      _timerState = TimerState.running;
      _timerPhase = TimerPhase.work;
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _tick();
    });

    notifyListeners();
  }

  // Track announced cues
  bool _announcedHalfway = false;
  bool _announcedTenSeconds = false;
  bool _announcedNextRound = false;

  /// Calculate total workout duration in seconds
  int get _totalWorkoutDuration {
    int total = 0;
    for (final interval in intervals) {
      // Skip stopwatch intervals (duration 0)
      if (interval.duration > 0) {
        total += interval.duration;
      }
    }
    return total;
  }

  void _tick() {
    _elapsedSeconds++;
    _intervalElapsedSeconds++;

    final interval = currentInterval;
    if (interval == null) {
      _completeWorkout();
      return;
    }

    // Track total work/rest time
    if (interval.isWork) {
      _totalWorkSeconds++;
    } else if (interval.isRest) {
      _totalRestSeconds++;
    }

    // Get effective duration (considers dynamic rest for Work/Rest)
    final effectiveDuration = _effectiveIntervalDuration;

    // For stopwatch intervals (duration 0), just count up
    if (interval.isStopwatch && effectiveDuration == 0) {
      notifyListeners();
      return;
    }

    final remaining = effectiveDuration - _intervalElapsedSeconds;

    // Halfway announcement - works for all timer types
    if (!_announcedHalfway) {
      final totalDuration = _totalWorkoutDuration;
      final halfwayPoint = totalDuration ~/ 2;
      // Announce halfway when total elapsed time reaches halfway point
      if (halfwayPoint > 0 && _elapsedSeconds == halfwayPoint) {
        _audioService.playHalfway();
        _announcedHalfway = true;
      }
    }

    // Warning sounds at 10 seconds remaining in interval
    if (remaining == 10 && !_announcedTenSeconds) {
      _audioService.playTenSeconds();
      _hapticsService.timerAlert();
      _announcedTenSeconds = true;
    }
    // Reset 10-second flag when we move past 10 seconds remaining
    if (remaining > 10) {
      _announcedTenSeconds = false;
    }

    // "Next round" voice announcement at 5 seconds (before 3, 2, 1 countdown)
    // Only announce if there's another work interval coming (not rest)
    if (remaining == 5 && !_announcedNextRound && _currentIntervalIndex < intervals.length - 1) {
      final nextInterval = intervals[_currentIntervalIndex + 1];
      if (nextInterval.isWork) {
        _audioService.playNextRoundVoice();
      }
      _announcedNextRound = true;
    }

    // Countdown sounds (3, 2, 1)
    if (remaining <= 3 && remaining > 0) {
      _audioService.playCountdown(remaining);
      _hapticsService.countdown();
    }

    // Check if current interval is complete
    if (remaining <= 0) {
      _advanceToNextInterval();
      return;
    }

    notifyListeners();
  }

  void _advanceToNextInterval() {
    _intervalElapsedSeconds = 0;
    _announcedTenSeconds = false;
    _announcedNextRound = false;
    _currentIntervalIndex++;

    // Check if all intervals completed
    if (_currentIntervalIndex >= intervals.length) {
      _completeWorkout();
      return;
    }

    final newInterval = currentInterval!;

    // Update state based on interval type
    if (newInterval.isRest) {
      _timerState = TimerState.rest;
      _timerPhase = TimerPhase.rest;
      _audioService.playRest();
      _hapticsService.trigger(HapticType.medium);
    } else {
      _timerState = TimerState.running;
      _timerPhase = TimerPhase.work;
      // Increment round when entering a new work interval
      _currentRound++;
      _audioService.playGo();
      _hapticsService.timerAlert();
    }

    notifyListeners();
  }

  // Track if we paused during countdown
  bool _pausedDuringCountdown = false;

  void pauseTimer() {
    if (_timerState != TimerState.running &&
        _timerState != TimerState.rest &&
        _timerState != TimerState.countdown) {
      return;
    }

    _pausedDuringCountdown = _timerState == TimerState.countdown;
    _timer?.cancel();
    _timerState = TimerState.paused;
    _hapticsService.buttonTap();
    notifyListeners();
  }

  void _resumeTimer() {
    if (_pausedDuringCountdown) {
      // Resume countdown
      _timerState = TimerState.countdown;
      _pausedDuringCountdown = false;
      _startCountdownTimer();
    } else {
      _timerState =
          _timerPhase == TimerPhase.rest ? TimerState.rest : TimerState.running;

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _tick();
      });
    }

    _hapticsService.buttonTap();
    notifyListeners();
  }

  void toggleTimer() {
    if (isRunning || isRest || isCountdown) {
      pauseTimer();
    } else {
      startTimer();
    }
  }

  void resetTimer() {
    _timer?.cancel();
    _timerState = TimerState.idle;
    _timerPhase = TimerPhase.countdown;
    _elapsedSeconds = 0;
    _remainingSeconds = 0;
    _currentRound = 1;
    _currentMovementIndex = 0;
    _currentIntervalIndex = 0;
    _intervalElapsedSeconds = 0;
    _dynamicRestDuration = 0;
    _totalWorkSeconds = 0;
    _totalRestSeconds = 0;
    _finalWorkRound = null;
    _finalRestRound = null;
    _counter = 0;
    _currentSession = null;
    _sessionStartTime = null;
    _announcedHalfway = false;
    _announcedTenSeconds = false;
    _announcedNextRound = false;
    _pausedDuringCountdown = false;
    notifyListeners();
  }

  void skipMovement() {
    if (_currentWorkout == null) return;

    if (_currentMovementIndex < _currentWorkout!.movements.length - 1) {
      _currentMovementIndex++;
      _audioService.playNextRoundBeep();
      _hapticsService.buttonTap();
      notifyListeners();
    }
  }

  void previousMovement() {
    if (_currentMovementIndex > 0) {
      _currentMovementIndex--;
      _hapticsService.buttonTap();
      notifyListeners();
    }
  }

  void _completeWorkout() {
    _timer?.cancel();
    // Preserve round counts before changing state (getters depend on state)
    _finalWorkRound = currentWorkRound;
    _finalRestRound = currentRestRound;
    _timerState = TimerState.completed;
    _audioService.playComplete();
    _hapticsService.workoutComplete();
    _completeSession();
    notifyListeners();
  }

  void completeEarly() {
    _completeWorkout();
  }

  // Dynamic rest duration for Work/Rest timer (matches previous work duration)
  int _dynamicRestDuration = 0;

  /// Manually complete the current interval and move to next
  /// Used for stopwatch intervals or "skip to rest" button
  void completeCurrentInterval() {
    if (intervals.isEmpty || _currentIntervalIndex >= intervals.length) {
      _completeWorkout();
      return;
    }

    // If it's the last interval, complete the workout
    if (_currentIntervalIndex >= intervals.length - 1) {
      _completeWorkout();
      return;
    }

    // For Work/Rest timer: capture work duration for the rest interval
    if (_currentWorkout?.type == WorkoutType.workRest && currentInterval?.isWork == true) {
      _dynamicRestDuration = _intervalElapsedSeconds;
    }

    _advanceToNextInterval();
  }

  /// Returns true if currently in a work interval
  bool get isCurrentWork => currentInterval?.isWork ?? true;

  /// Returns true if currently in a rest interval
  bool get isCurrentRest => currentInterval?.isRest ?? false;

  // Session tracking
  void _startSession() {
    final userId = _authProvider?.user?.id ?? 'anonymous';

    _currentSession = WorkoutSession(
      id: _uuid.v4(),
      userId: userId,
      workoutId: _currentWorkout?.id,
      workoutName: _currentWorkout?.name ?? 'Workout',
      workoutType: _currentWorkout?.type.name ?? 'custom',
      workoutSnapshot: _currentWorkout?.toJson() ?? {},
      status: SessionStatus.inProgress,
      startedAt: DateTime.now(),
    );
  }

  Future<void> _completeSession() async {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.copyWith(
      status: SessionStatus.completed,
      durationSeconds: _elapsedSeconds,
      roundsCompleted: _currentRound,
      completedAt: DateTime.now(),
    );

    await _saveSession(_currentSession!);
  }

  Future<void> abandonSession() async {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.copyWith(
      status: SessionStatus.abandoned,
      durationSeconds: _elapsedSeconds,
      roundsCompleted: _currentRound,
      completedAt: DateTime.now(),
    );

    await _saveSession(_currentSession!);

    resetTimer();
  }

  Future<void> _saveSession(WorkoutSession session) async {
    try {
      await _storageService.saveSession(session);
    } catch (e) {
      debugPrint('Failed to save session: $e');
    }
  }

  Future<void> saveWorkout(Workout workout) async {
    try {
      await _storageService.saveWorkout(workout);
    } catch (e) {
      debugPrint('Failed to save workout: $e');
      rethrow;
    }
  }

  // Manual timer setup
  void setManualTimer({
    required WorkoutType type,
    int? totalSeconds,
    int? workSeconds,
    int? restSeconds,
    int? rounds,
    int? intervalSeconds,
    bool hasCountdown = true,
    int countdownSeconds = 5,
    String? notes,
  }) {
    final userId = _authProvider?.user?.id ?? 'anonymous';

    // Build intervals based on timer type
    final intervals = _buildIntervals(
      type: type,
      totalSeconds: totalSeconds,
      workSeconds: workSeconds,
      restSeconds: restSeconds,
      rounds: rounds,
      intervalSeconds: intervalSeconds,
    );

    _currentWorkout = Workout(
      id: _uuid.v4(),
      userId: userId,
      name: type.displayName,
      notes: notes,
      type: type,
      timerConfig: TimerConfig(
        intervals: intervals,
        totalSeconds: totalSeconds,
        workSeconds: workSeconds,
        restSeconds: restSeconds,
        rounds: rounds,
        intervalSeconds: intervalSeconds,
        hasCountdown: hasCountdown,
        countdownSeconds: countdownSeconds,
      ),
      movements: [],
      createdAt: DateTime.now(),
    );

    resetTimer();
    notifyListeners();
  }

  /// Build intervals list based on timer type
  List<TimerInterval> _buildIntervals({
    required WorkoutType type,
    int? totalSeconds,
    int? workSeconds,
    int? restSeconds,
    int? rounds,
    int? intervalSeconds,
  }) {
    switch (type) {
      case WorkoutType.restTimer:
        // Rest timer: 1 work interval (countdown)
        return [TimerInterval(duration: totalSeconds ?? 60, type: 'work')];

      case WorkoutType.forTime:
        // For Time: 1 work interval (0 = stopwatch if no cap)
        return [TimerInterval(duration: totalSeconds ?? 0, type: 'work')];

      case WorkoutType.amrap:
        // AMRAP: 1 work interval with total duration
        return [TimerInterval(duration: totalSeconds ?? 600, type: 'work')];

      case WorkoutType.stopwatch:
        // Stopwatch: 1 work interval with duration 0
        return [const TimerInterval(duration: 0, type: 'work')];

      case WorkoutType.emom:
        // EMOM: N work intervals with interval duration
        final numRounds = rounds ?? 10;
        final intervalDuration = intervalSeconds ?? 60;
        return List.generate(
          numRounds,
          (_) => TimerInterval(duration: intervalDuration, type: 'work'),
        );

      case WorkoutType.tabata:
      case WorkoutType.customInterval:
        // Tabata/Custom: alternating work/rest intervals
        final numRounds = rounds ?? 8;
        final work = workSeconds ?? 20;
        final rest = restSeconds ?? 10;
        final List<TimerInterval> result = [];
        for (int i = 0; i < numRounds; i++) {
          result.add(TimerInterval(duration: work, type: 'work'));
          if (rest > 0 && i < numRounds - 1) {
            result.add(TimerInterval(duration: rest, type: 'rest'));
          }
        }
        return result;

      case WorkoutType.workRest:
        // Work/Rest: work intervals with manual stop, rest = work duration
        final numRounds = rounds ?? 5;
        final List<TimerInterval> result = [];
        for (int i = 0; i < numRounds; i++) {
          // Work until manual stop (duration 0)
          result.add(const TimerInterval(duration: 0, type: 'work'));
          if (i < numRounds - 1) {
            // Rest will be set dynamically based on work duration
            result.add(const TimerInterval(duration: 0, type: 'rest'));
          }
        }
        return result;

      default:
        return [TimerInterval(duration: totalSeconds ?? 0, type: 'work')];
    }
  }

  void clearWorkout() {
    _currentWorkout = null;
    _workoutInput = '';
    _parseError = null;
    resetTimer();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
