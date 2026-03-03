import 'movement.dart';

enum WorkoutType {
  amrap,
  emom,
  forTime,
  tabata,
  custom,
  stopwatch,
  restTimer,
  workRest,
  customInterval,
}

extension WorkoutTypeExtension on WorkoutType {
  String get displayName {
    switch (this) {
      case WorkoutType.amrap:
        return 'AMRAP';
      case WorkoutType.emom:
        return 'EMOM';
      case WorkoutType.forTime:
        return 'For Time';
      case WorkoutType.tabata:
        return 'Tabata';
      case WorkoutType.custom:
        return 'Custom';
      case WorkoutType.stopwatch:
        return 'Stopwatch';
      case WorkoutType.restTimer:
        return 'Rest';
      case WorkoutType.workRest:
        return 'Work/Rest';
      case WorkoutType.customInterval:
        return 'Custom Intervals';
    }
  }

  static WorkoutType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'amrap':
        return WorkoutType.amrap;
      case 'emom':
        return WorkoutType.emom;
      case 'for time':
      case 'fortime':
      case 'for_time':
        return WorkoutType.forTime;
      case 'tabata':
        return WorkoutType.tabata;
      case 'stopwatch':
        return WorkoutType.stopwatch;
      case 'rest timer':
      case 'resttimer':
      case 'rest_timer':
        return WorkoutType.restTimer;
      case 'work/rest':
      case 'workrest':
      case 'work_rest':
        return WorkoutType.workRest;
      case 'custom intervals':
      case 'customintervals':
      case 'custom_intervals':
      case 'custom_interval':
      case 'custominterval':
        return WorkoutType.customInterval;
      default:
        return WorkoutType.custom;
    }
  }
}

/// Represents a single timer interval (work or rest period)
class TimerInterval {
  final int duration; // seconds, 0 = stopwatch/manual stop
  final String type; // "work" or "rest"
  final bool repeat; // for infinite/repeat intervals

  const TimerInterval({
    required this.duration,
    this.type = 'work',
    this.repeat = false,
  });

  bool get isWork => type == 'work';
  bool get isRest => type == 'rest';
  bool get isStopwatch => duration == 0;

  factory TimerInterval.fromJson(Map<String, dynamic> json) {
    return TimerInterval(
      duration: json['duration'] as int? ?? 0,
      type: json['type'] as String? ?? 'work',
      repeat: json['repeat'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'duration': duration,
      'type': type,
      'repeat': repeat,
    };
  }

  TimerInterval copyWith({
    int? duration,
    String? type,
    bool? repeat,
  }) {
    return TimerInterval(
      duration: duration ?? this.duration,
      type: type ?? this.type,
      repeat: repeat ?? this.repeat,
    );
  }
}

class TimerConfig {
  final List<TimerInterval> intervals;
  final bool hasCountdown;
  final int countdownSeconds;

  // Legacy fields for backwards compatibility
  final int? totalSeconds;
  final int? workSeconds;
  final int? restSeconds;
  final int? rounds;
  final int? intervalSeconds;

  TimerConfig({
    this.intervals = const [],
    this.hasCountdown = true,
    this.countdownSeconds = 5,
    this.totalSeconds,
    this.workSeconds,
    this.restSeconds,
    this.rounds,
    this.intervalSeconds,
  });

  /// Total duration of all intervals
  int get totalDuration => intervals.fold(0, (sum, i) => sum + i.duration);

  /// Number of work intervals (rounds)
  int get workRounds => intervals.where((i) => i.isWork).length;

  /// Check if this is a stopwatch timer (first interval has duration 0)
  bool get isStopwatch => intervals.isNotEmpty && intervals.first.duration == 0;

  factory TimerConfig.fromJson(Map<String, dynamic> json) {
    final intervalsList = (json['intervals'] as List<dynamic>?)
            ?.map((i) => TimerInterval.fromJson(i as Map<String, dynamic>))
            .toList() ??
        [];

    return TimerConfig(
      intervals: intervalsList,
      hasCountdown: json['has_countdown'] as bool? ?? true,
      countdownSeconds: json['countdown_seconds'] as int? ?? 5,
      totalSeconds: json['total_seconds'] as int?,
      workSeconds: json['work_seconds'] as int?,
      restSeconds: json['rest_seconds'] as int?,
      rounds: json['rounds'] as int?,
      intervalSeconds: json['interval_seconds'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intervals': intervals.map((i) => i.toJson()).toList(),
      'has_countdown': hasCountdown,
      'countdown_seconds': countdownSeconds,
      'total_seconds': totalSeconds,
      'work_seconds': workSeconds,
      'rest_seconds': restSeconds,
      'rounds': rounds,
      'interval_seconds': intervalSeconds,
    };
  }

  TimerConfig copyWith({
    List<TimerInterval>? intervals,
    bool? hasCountdown,
    int? countdownSeconds,
    int? totalSeconds,
    int? workSeconds,
    int? restSeconds,
    int? rounds,
    int? intervalSeconds,
  }) {
    return TimerConfig(
      intervals: intervals ?? this.intervals,
      hasCountdown: hasCountdown ?? this.hasCountdown,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      workSeconds: workSeconds ?? this.workSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      rounds: rounds ?? this.rounds,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
    );
  }

  /// True if this config matches another for timer behavior (intervals, countdown).
  bool sameConfigAs(TimerConfig other) {
    if (hasCountdown != other.hasCountdown ||
        countdownSeconds != other.countdownSeconds) {
      return false;
    }
    if (intervals.length != other.intervals.length) return false;
    for (var i = 0; i < intervals.length; i++) {
      final a = intervals[i];
      final b = other.intervals[i];
      if (a.duration != b.duration || a.type != b.type || a.repeat != b.repeat) {
        return false;
      }
    }
    return true;
  }
}

class Workout {
  final String id;
  final String userId;
  final String name;
  final String? rawInput;
  final String? notes;
  final WorkoutType type;
  final TimerConfig timerConfig;
  final List<Movement> movements;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Workout({
    required this.id,
    required this.userId,
    required this.name,
    this.rawInput,
    this.notes,
    required this.type,
    required this.timerConfig,
    required this.movements,
    this.isFavorite = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      rawInput: json['raw_input'] as String?,
      notes: json['notes'] as String?,
      type: WorkoutTypeExtension.fromString(json['type'] as String),
      timerConfig: TimerConfig.fromJson(
        json['timer_config'] as Map<String, dynamic>? ?? {},
      ),
      movements: (json['movements'] as List<dynamic>?)
              ?.map((m) => Movement.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      isFavorite: json['is_favorite'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'raw_input': rawInput,
      'notes': notes,
      'type': type.name,
      'timer_config': timerConfig.toJson(),
      'movements': movements.map((m) => m.toJson()).toList(),
      'is_favorite': isFavorite,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Workout copyWith({
    String? id,
    String? userId,
    String? name,
    String? rawInput,
    String? notes,
    WorkoutType? type,
    TimerConfig? timerConfig,
    List<Movement>? movements,
    bool? isFavorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Workout(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      rawInput: rawInput ?? this.rawInput,
      notes: notes ?? this.notes,
      type: type ?? this.type,
      timerConfig: timerConfig ?? this.timerConfig,
      movements: movements ?? this.movements,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedDuration {
    final seconds = timerConfig.totalSeconds;
    if (seconds == null) return '--:--';

    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String get movementsPreview {
    if (movements.isEmpty) return 'No movements';
    if (movements.length <= 3) {
      return movements.map((m) => m.displayText).join(', ');
    }
    return '${movements.take(3).map((m) => m.displayText).join(', ')} +${movements.length - 3} more';
  }

  /// True if this workout has the same type and timer config as another (e.g. same time cap, countdown, rounds).
  bool hasSameConfigAs(Workout other) {
    if (type != other.type) return false;
    return timerConfig.sameConfigAs(other.timerConfig);
  }
}
