import '../models/workout.dart';

const int maxWorkoutNameLength = 18;

/// Propose a short workout name: TYPE - Mon DD
/// Result is capped at [maxWorkoutNameLength] for display consistency.
String proposeWorkoutName(Workout? workout) {
  if (workout == null) return '';
  return defaultManualWorkoutName(workout.type);
}

/// Fallback name when no description is available (type + date).
String fallbackWorkoutName(Workout? workout) {
  if (workout == null) return '';
  return defaultManualWorkoutName(workout.type);
}

/// Default name for manual timer save (type + date). Used when user doesn't enter a name.
String defaultManualWorkoutName(WorkoutType type) {
  final typeStr = type.displayName.toUpperCase();
  final date = DateTime.now();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final dateStr = '${months[date.month - 1]} ${date.day}';
  final name = '$typeStr - $dateStr';
  return name.length <= maxWorkoutNameLength
      ? name
      : '${name.substring(0, maxWorkoutNameLength - 3)}...';
}

/// Truncate a display name to [maxWorkoutNameLength] with ellipsis.
String displayWorkoutName(String name) {
  if (name.length <= maxWorkoutNameLength) return name;
  return '${name.substring(0, maxWorkoutNameLength - 3)}...';
}
