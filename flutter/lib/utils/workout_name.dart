import '../models/workout.dart';

const int maxWorkoutNameLength = 18;

/// Propose a short workout name from the workout description (notes, rawInput, or movements).
/// Result is capped at [maxWorkoutNameLength] for display consistency.
String proposeWorkoutName(Workout? workout) {
  if (workout == null) return '';

  const max = maxWorkoutNameLength;

  String fromText(String text) {
    final line = text.trim().split('\n').firstOrNull?.trim() ?? '';
    final collapsed = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= max) return collapsed;
    return '${collapsed.substring(0, max - 3)}...';
  }

  if (workout.notes != null && workout.notes!.trim().isNotEmpty) {
    final name = fromText(workout.notes!);
    if (name.isNotEmpty) return name;
  }
  if (workout.rawInput != null && workout.rawInput!.trim().isNotEmpty) {
    final name = fromText(workout.rawInput!);
    if (name.isNotEmpty) return name;
  }

  // Fallback: type + first movement names
  final type = workout.type.displayName.toUpperCase();
  final movementNames = workout.movements
      .where((m) => m.name.trim().isNotEmpty)
      .map((m) => m.name.trim())
      .take(2)
      .toList();
  final combined = movementNames.isNotEmpty
      ? '$type ${movementNames.join(', ')}'
      : type;
  final collapsed = combined.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (collapsed.length <= max) return collapsed;
  final fromMovements = '${collapsed.substring(0, max - 3)}...';
  if (fromMovements.isNotEmpty) return fromMovements;

  return fallbackWorkoutName(workout);
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
