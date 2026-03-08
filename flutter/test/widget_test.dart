import 'package:flutter_test/flutter_test.dart';

import 'package:ai_wod_timer/models/workout.dart';
import 'package:ai_wod_timer/utils/workout_name.dart';

// ---------------------------------------------------------------------------
// WorkoutType — display names and round-trip parsing
// ---------------------------------------------------------------------------

void main() {
  group('WorkoutType.displayName', () {
    test('returns correct label for every type', () {
      expect(WorkoutType.amrap.displayName, 'AMRAP');
      expect(WorkoutType.emom.displayName, 'EMOM');
      expect(WorkoutType.forTime.displayName, 'For Time');
      expect(WorkoutType.tabata.displayName, 'Tabata');
      expect(WorkoutType.custom.displayName, 'Custom');
      expect(WorkoutType.stopwatch.displayName, 'Stopwatch');
      expect(WorkoutType.restTimer.displayName, 'Rest');
      expect(WorkoutType.workRest.displayName, 'Work/Rest');
      expect(WorkoutType.customInterval.displayName, 'Intervals');
    });

    test('covers all enum values — fails if a new type is added without a display name', () {
      for (final type in WorkoutType.values) {
        expect(
          type.displayName,
          isNotEmpty,
          reason: '${type.name} has no displayName',
        );
      }
    });
  });

  group('WorkoutTypeExtension.fromString', () {
    test('parses canonical names', () {
      expect(WorkoutTypeExtension.fromString('amrap'), WorkoutType.amrap);
      expect(WorkoutTypeExtension.fromString('emom'), WorkoutType.emom);
      expect(WorkoutTypeExtension.fromString('tabata'), WorkoutType.tabata);
      expect(WorkoutTypeExtension.fromString('stopwatch'), WorkoutType.stopwatch);
    });

    test('parses for_time aliases', () {
      expect(WorkoutTypeExtension.fromString('for_time'), WorkoutType.forTime);
      expect(WorkoutTypeExtension.fromString('for time'), WorkoutType.forTime);
      expect(WorkoutTypeExtension.fromString('fortime'), WorkoutType.forTime);
    });

    test('parses work_rest aliases', () {
      expect(WorkoutTypeExtension.fromString('work_rest'), WorkoutType.workRest);
      expect(WorkoutTypeExtension.fromString('work/rest'), WorkoutType.workRest);
      expect(WorkoutTypeExtension.fromString('workrest'), WorkoutType.workRest);
    });
  });

  // ---------------------------------------------------------------------------
  // displayWorkoutName — truncation logic
  // ---------------------------------------------------------------------------

  group('displayWorkoutName', () {
    test('returns name unchanged when within limit', () {
      const name = 'AMRAP - Mar 8';
      expect(displayWorkoutName(name), name);
    });

    test('truncates with ellipsis when over 18 chars', () {
      const long = 'CUSTOM INTERVAL - Mar 8'; // 23 chars
      final result = displayWorkoutName(long);
      expect(result.length, maxWorkoutNameLength);
      expect(result.endsWith('...'), isTrue);
    });

    test('handles exactly 18 chars without truncation', () {
      const exact = '123456789012345678'; // exactly 18
      expect(displayWorkoutName(exact), exact);
    });
  });
}
