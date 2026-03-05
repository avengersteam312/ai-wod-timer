enum SessionStatus {
  inProgress,
  completed,
  abandoned,
}

extension SessionStatusExtension on SessionStatus {
  String get displayName {
    switch (this) {
      case SessionStatus.inProgress:
        return 'In Progress';
      case SessionStatus.completed:
        return 'Completed';
      case SessionStatus.abandoned:
        return 'Abandoned';
    }
  }

  static SessionStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'in_progress':
      case 'inprogress':
        return SessionStatus.inProgress;
      case 'completed':
        return SessionStatus.completed;
      case 'abandoned':
        return SessionStatus.abandoned;
      default:
        return SessionStatus.inProgress;
    }
  }
}

class WorkoutSession {
  final String id;
  final String userId;
  final String? workoutId;
  final String workoutName;
  final String workoutType;
  final Map<String, dynamic> workoutSnapshot;
  final SessionStatus status;
  final int? durationSeconds;
  final int? roundsCompleted;
  final String? notes;
  final DateTime startedAt;
  final DateTime? completedAt;

  WorkoutSession({
    required this.id,
    required this.userId,
    this.workoutId,
    required this.workoutName,
    required this.workoutType,
    required this.workoutSnapshot,
    required this.status,
    this.durationSeconds,
    this.roundsCompleted,
    this.notes,
    required this.startedAt,
    this.completedAt,
  });

  /// Sentinel for missing timestamp (do not use DateTime.now() — corrupts sorting/history).
  static final DateTime _epoch = DateTime.utc(1970, 1, 1);

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    final startedAtRaw = json['started_at'] as String?;
    final completedAtRaw = json['completed_at'] as String?;
    return WorkoutSession(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      workoutId: json['workout_id'] as String?,
      workoutName: (json['workout_name'] as String?) ?? '',
      workoutType: (json['workout_type'] as String?) ?? 'custom',
      workoutSnapshot: json['workout_snapshot'] as Map<String, dynamic>? ?? {},
      status: SessionStatusExtension.fromString((json['status'] as String?) ?? 'in_progress'),
      durationSeconds: json['duration_seconds'] as int?,
      roundsCompleted: json['rounds_completed'] as int?,
      notes: json['notes'] as String?,
      startedAt: startedAtRaw != null && startedAtRaw.isNotEmpty
          ? DateTime.parse(startedAtRaw)
          : _epoch,
      completedAt: completedAtRaw != null && completedAtRaw.isNotEmpty
          ? DateTime.parse(completedAtRaw)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'workout_id': workoutId,
      'workout_name': workoutName,
      'workout_type': workoutType,
      'workout_snapshot': workoutSnapshot,
      'status': status.name,
      'duration_seconds': durationSeconds,
      'rounds_completed': roundsCompleted,
      'notes': notes,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  WorkoutSession copyWith({
    String? id,
    String? userId,
    String? workoutId,
    String? workoutName,
    String? workoutType,
    Map<String, dynamic>? workoutSnapshot,
    SessionStatus? status,
    int? durationSeconds,
    int? roundsCompleted,
    String? notes,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      workoutId: workoutId ?? this.workoutId,
      workoutName: workoutName ?? this.workoutName,
      workoutType: workoutType ?? this.workoutType,
      workoutSnapshot: workoutSnapshot ?? this.workoutSnapshot,
      status: status ?? this.status,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      roundsCompleted: roundsCompleted ?? this.roundsCompleted,
      notes: notes ?? this.notes,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  String get formattedDuration {
    if (durationSeconds == null) return '--:--';

    final hours = durationSeconds! ~/ 3600;
    final minutes = (durationSeconds! % 3600) ~/ 60;
    final secs = durationSeconds! % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(startedAt);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${startedAt.month}/${startedAt.day}/${startedAt.year}';
    }
  }
}
