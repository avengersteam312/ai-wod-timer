import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:ai_wod_timer/models/workout.dart';
import 'package:ai_wod_timer/models/workout_session.dart';
import 'package:ai_wod_timer/services/offline_storage_service.dart';

Workout _buildWorkout({
  required String id,
  required String name,
  required DateTime createdAt,
}) {
  return Workout(
    id: id,
    userId: 'user-123',
    name: name,
    type: WorkoutType.amrap,
    timerConfig: TimerConfig(
      intervals: const [TimerInterval(duration: 600, type: 'work')],
      totalSeconds: 600,
      rounds: 1,
    ),
    movements: const [],
    createdAt: createdAt,
  );
}

WorkoutSession _buildSession({
  required String id,
  required DateTime startedAt,
}) {
  return WorkoutSession(
    id: id,
    userId: 'user-123',
    workoutName: 'Fran',
    workoutType: 'emom',
    workoutSnapshot: const {},
    status: SessionStatus.completed,
    durationSeconds: 120,
    startedAt: startedAt,
  );
}

Future<void> _openBoxes() async {
  await Hive.openBox<String>('workouts');
  await Hive.openBox<String>('sessions');
  await Hive.openBox<Map>('sync_queue');
  await Hive.openBox<dynamic>('preferences');
}

Future<T> _runWithSuppressedDebugPrint<T>(Future<T> Function() action) async {
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {};
  try {
    return await action();
  } finally {
    debugPrint = originalDebugPrint;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late OfflineStorageService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'offline-storage-service-test',
    );
    Hive.init(tempDir.path);
    await _openBoxes();
    service = OfflineStorageService.test();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('getWorkouts sorts descending and skips corrupt entries', () async {
    await service.saveWorkout(
      _buildWorkout(
        id: 'older',
        name: 'Older',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await service.saveWorkout(
      _buildWorkout(
        id: 'newer',
        name: 'Newer',
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    );
    await Hive.box<String>('workouts').put('broken', '{not json');

    final workouts = await _runWithSuppressedDebugPrint(
      () => service.getWorkouts('user-123'),
    );

    expect(workouts.map((w) => w.id), ['newer', 'older']);
  });

  test('getWorkout and getSession return null for malformed records', () async {
    await Hive.box<String>('workouts').put('bad-workout', '{not json');
    await Hive.box<String>('sessions').put('bad-session', '{not json');

    await _runWithSuppressedDebugPrint(() async {
      expect(await service.getWorkout('bad-workout'), isNull);
      expect(await service.getSession('bad-session'), isNull);
    });
  });

  test('getSessions sorts descending and skips corrupt entries', () async {
    await service.saveSession(
      _buildSession(
        id: 'older-session',
        startedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await service.saveSession(
      _buildSession(
        id: 'newer-session',
        startedAt: DateTime.utc(2026, 1, 2),
      ),
    );
    await Hive.box<String>('sessions').put('broken', '{not json');

    final sessions = await _runWithSuppressedDebugPrint(
      () => service.getSessions('user-123'),
    );

    expect(sessions.map((s) => s.id), ['newer-session', 'older-session']);
  });

  test('getSyncQueue sorts ascending and skips malformed operations', () async {
    await service.addToSyncQueue(
      SyncOperation(
        id: 'later',
        type: SyncOperationType.update,
        entity: SyncEntityType.workout,
        entityId: 'w2',
        data: const {'id': 'w2'},
        timestamp: DateTime.utc(2026, 1, 1, 0, 0, 2),
      ),
    );
    await service.addToSyncQueue(
      SyncOperation(
        id: 'earlier',
        type: SyncOperationType.create,
        entity: SyncEntityType.workout,
        entityId: 'w1',
        data: const {'id': 'w1'},
        timestamp: DateTime.utc(2026, 1, 1, 0, 0, 1),
      ),
    );
    await Hive.box<Map>('sync_queue').put('broken', {'type': 'bad'});

    final queue = await _runWithSuppressedDebugPrint(
      () => service.getSyncQueue(),
    );

    expect(queue.map((operation) => operation.id), ['earlier', 'later']);
  });

  test('preferences and clearAll remove persisted data', () async {
    await service.saveWorkout(
      _buildWorkout(
        id: 'workout-1',
        name: 'Workout 1',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await service.saveSession(
      _buildSession(
        id: 'session-1',
        startedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await service.addToSyncQueue(
      SyncOperation(
        id: 'queue-1',
        type: SyncOperationType.create,
        entity: SyncEntityType.session,
        entityId: 'session-1',
        timestamp: DateTime.utc(2026, 1, 1),
      ),
    );
    await service.setPreference('voice_enabled', true);

    expect(service.getPreference<bool>('voice_enabled'), isTrue);

    await service.removePreference('voice_enabled');
    expect(service.getPreference<bool>('voice_enabled'), isNull);

    await service.setPreference('voice_enabled', true);
    await service.clearAll();

    expect(await service.getWorkouts('user-123'), isEmpty);
    expect(await service.getSessions('user-123'), isEmpty);
    expect(await service.getSyncQueue(), isEmpty);
    expect(service.getPreference<bool>('voice_enabled'), isNull);
  });
}
