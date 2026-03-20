import 'package:flutter/foundation.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:ai_wod_timer/models/user.dart';
import 'package:ai_wod_timer/models/workout.dart';
import 'package:ai_wod_timer/models/workout_session.dart';
import 'package:ai_wod_timer/providers/auth_provider.dart';
import 'package:ai_wod_timer/providers/workout_provider.dart';
import 'package:ai_wod_timer/services/api_service.dart';
import 'package:ai_wod_timer/services/haptics_service.dart';
import 'package:ai_wod_timer/services/offline_storage_service.dart';
import 'package:ai_wod_timer/services/sync_service.dart';

class TestAuthProvider extends AuthProvider {
  TestAuthProvider(this._testUser);

  final AppUser? _testUser;

  @override
  AppUser? get user => _testUser;

  @override
  bool get isAuthenticated => _testUser != null;
}

class InMemoryOfflineStorageService extends OfflineStorageService {
  InMemoryOfflineStorageService() : super.test();

  final Map<String, Workout> workouts = {};
  final Map<String, WorkoutSession> sessions = {};
  final Map<String, SyncOperation> queue = {};

  @override
  Future<void> init() async {}

  @override
  Future<void> saveWorkout(Workout workout) async {
    workouts[workout.id] = workout;
  }

  @override
  Future<void> saveWorkouts(List<Workout> values) async {
    for (final workout in values) {
      workouts[workout.id] = workout;
    }
  }

  @override
  Future<List<Workout>> getWorkouts(String userId) async {
    final values = workouts.values.where((w) => w.userId == userId).toList();
    values.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return values;
  }

  @override
  Future<void> deleteWorkout(String id) async {
    workouts.remove(id);
  }

  @override
  Future<void> saveSession(WorkoutSession session) async {
    sessions[session.id] = session;
  }

  @override
  Future<void> deleteSession(String id) async {
    sessions.remove(id);
  }

  @override
  Future<void> addToSyncQueue(SyncOperation operation) async {
    queue[operation.id] = operation;
  }

  @override
  Future<List<SyncOperation>> getSyncQueue() async {
    final values = queue.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return values;
  }

  @override
  Future<void> removeFromSyncQueue(String id) async {
    queue.remove(id);
  }
}

class ThrowingOfflineStorageService extends InMemoryOfflineStorageService {
  @override
  Future<void> saveWorkout(Workout workout) {
    throw StateError('storage failed');
  }
}

Workout _buildWorkout({
  required String id,
  required String name,
}) {
  return Workout(
    id: id,
    userId: 'user-123',
    name: name,
    type: WorkoutType.emom,
    timerConfig: TimerConfig(
      intervals: const [TimerInterval(duration: 60, type: 'work')],
      totalSeconds: 60,
      rounds: 1,
    ),
    movements: const [],
    createdAt: DateTime.utc(2026, 1, 1),
  );
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
  setUpAll(() {
    dotenv.loadFromString(
      envString: '''
API_BASE_URL=http://localhost:8000
AUTH_ENABLED=false
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=
''',
    );
    HapticsService.instance.setEnabled(false);
  });

  test('setManualTimer builds intervals and exposes matching UI state', () {
    final provider = WorkoutProvider(
      syncService: SyncService.test(
        storage: InMemoryOfflineStorageService(),
        hasSupabaseConfig: () => false,
      ),
    );

    provider.setManualTimer(
      type: WorkoutType.tabata,
      workSeconds: 20,
      restSeconds: 10,
      rounds: 3,
      hasCountdown: true,
      countdownSeconds: 7,
      notes: 'Sprint work',
    );

    expect(provider.currentWorkout, isNotNull);
    expect(provider.currentWorkout!.type, WorkoutType.tabata);
    expect(provider.currentWorkout!.timerConfig.intervals.length, 5);
    expect(provider.currentWorkout!.timerConfig.intervals.first.duration, 20);
    expect(provider.currentWorkout!.timerConfig.intervals[1].type, 'rest');
    expect(provider.shouldShowRoundCounter, isTrue);
    expect(provider.shouldShowManualCounter, isFalse);
    expect(provider.loadedFromWorkoutId, isNull);
  });

  test('setWorkout resets timer state and keeps saved workout linkage', () {
    final provider = WorkoutProvider(
      syncService: SyncService.test(
        storage: InMemoryOfflineStorageService(),
        hasSupabaseConfig: () => false,
      ),
    );
    provider.setManualTimer(
      type: WorkoutType.amrap,
      totalSeconds: 120,
      hasCountdown: false,
    );
    provider.incrementCounter();
    provider.startTimer();

    final savedWorkout = _buildWorkout(id: 'saved-1', name: 'Fran').copyWith(
      rawInput: '21-15-9',
    );
    provider.setWorkout(savedWorkout, fromSavedWorkoutId: savedWorkout.id);

    expect(provider.currentWorkout?.id, 'saved-1');
    expect(provider.timerState, TimerState.idle);
    expect(provider.counter, 0);
    expect(provider.workoutInput, '21-15-9');
    expect(provider.loadedFromWorkoutId, 'saved-1');
  });

  test('startTimer advances emom rounds and completes after final interval',
      () {
    final provider = WorkoutProvider(
      syncService: SyncService.test(
        storage: InMemoryOfflineStorageService(),
        hasSupabaseConfig: () => false,
      ),
    );
    provider.setManualTimer(
      type: WorkoutType.emom,
      rounds: 2,
      intervalSeconds: 5,
      hasCountdown: false,
    );

    fakeAsync((async) {
      provider.startTimer();
      expect(provider.timerState, TimerState.running);
      expect(provider.currentWorkRound, 1);

      async.elapse(const Duration(seconds: 5));
      expect(provider.timerState, TimerState.running);
      expect(provider.currentRound, 2);
      expect(provider.currentWorkRound, 2);

      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();
      expect(provider.timerState, TimerState.completed);
      expect(provider.elapsedSeconds, 10);
      expect(provider.currentWorkRound, 2);
    });
  });

  test('work rest timers derive dynamic rest from completed work interval', () {
    final provider = WorkoutProvider(
      syncService: SyncService.test(
        storage: InMemoryOfflineStorageService(),
        hasSupabaseConfig: () => false,
      ),
    );
    provider.setManualTimer(
      type: WorkoutType.workRest,
      rounds: 2,
      hasCountdown: false,
    );

    fakeAsync((async) {
      provider.startTimer();
      async.elapse(const Duration(seconds: 3));

      provider.completeCurrentInterval();

      expect(provider.timerState, TimerState.rest);
      expect(provider.isCurrentRest, isTrue);
      expect(provider.currentRestRound, 1);
      expect(provider.currentWorkRound, 1);
    });
  });

  test('saveWorkout links current workout only when remote sync succeeds',
      () async {
    final storage = InMemoryOfflineStorageService();
    final remoteService = SyncService.test(
      storage: storage,
      hasSupabaseConfig: () => true,
      initialOnline: true,
      upsertRemoteWorkout: (_) async {},
    );
    final provider = WorkoutProvider(syncService: remoteService);
    final workout = _buildWorkout(id: 'saved-2', name: 'Cindy');
    provider.setWorkout(workout);

    final synced = await provider.saveWorkout(workout);

    expect(synced, isTrue);
    expect(provider.loadedFromWorkoutId, 'saved-2');
  });

  test('isWorkoutNameTaken is case-insensitive and respects excludeWorkoutId',
      () async {
    final storage = InMemoryOfflineStorageService();
    await storage.saveWorkout(_buildWorkout(id: 'w1', name: 'Fran'));
    await storage.saveWorkout(_buildWorkout(id: 'w2', name: 'Murph'));
    final provider = WorkoutProvider(
      syncService: SyncService.test(
        storage: storage,
        hasSupabaseConfig: () => false,
        initialOnline: false,
      ),
    );
    provider.updateAuth(
      TestAuthProvider(
        AppUser(
          id: 'user-123',
          email: 'test@example.com',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ),
    );

    expect(await provider.isWorkoutNameTaken('user-123', 'fran'), isTrue);
    expect(
      await provider.isWorkoutNameTaken(
        'user-123',
        'FRAN',
        excludeWorkoutId: 'w1',
      ),
      isFalse,
    );
  });

  test('countdown can be paused and resumed before entering work phase', () {
    final provider = WorkoutProvider(
      syncService: SyncService.test(
        storage: InMemoryOfflineStorageService(),
        hasSupabaseConfig: () => false,
      ),
    );
    provider.setManualTimer(
      type: WorkoutType.amrap,
      totalSeconds: 10,
      hasCountdown: true,
      countdownSeconds: 3,
    );

    fakeAsync((async) {
      provider.startTimer();
      expect(provider.timerState, TimerState.countdown);
      expect(provider.remainingSeconds, 3);

      async.elapse(const Duration(seconds: 1));
      expect(provider.remainingSeconds, 2);

      provider.pauseTimer();
      expect(provider.timerState, TimerState.paused);
      expect(provider.formattedTime, '00:02');

      async.elapse(const Duration(seconds: 2));
      expect(provider.remainingSeconds, 2);

      provider.startTimer();
      expect(provider.timerState, TimerState.countdown);

      async.elapse(const Duration(seconds: 2));
      expect(provider.timerState, TimerState.running);
      expect(provider.formattedTime, '00:10');
    });
  });

  test('pause during rest resumes into rest state before next work interval',
      () {
    final provider = WorkoutProvider(
      syncService: SyncService.test(
        storage: InMemoryOfflineStorageService(),
        hasSupabaseConfig: () => false,
      ),
    );
    provider.setManualTimer(
      type: WorkoutType.tabata,
      workSeconds: 2,
      restSeconds: 2,
      rounds: 2,
      hasCountdown: false,
    );

    fakeAsync((async) {
      provider.startTimer();
      async.elapse(const Duration(seconds: 2));

      expect(provider.timerState, TimerState.rest);
      expect(provider.isCurrentRest, isTrue);

      provider.pauseTimer();
      expect(provider.timerState, TimerState.paused);

      provider.startTimer();
      expect(provider.timerState, TimerState.rest);

      async.elapse(const Duration(seconds: 2));
      expect(provider.timerState, TimerState.running);
      expect(provider.currentRound, 2);
      expect(provider.currentWorkRound, 2);
    });
  });

  test('stopwatch counts up until manually completed', () {
    final provider = WorkoutProvider(
      syncService: SyncService.test(
        storage: InMemoryOfflineStorageService(),
        hasSupabaseConfig: () => false,
      ),
    );
    provider.setManualTimer(
      type: WorkoutType.stopwatch,
      hasCountdown: false,
    );

    fakeAsync((async) {
      provider.startTimer();
      async.elapse(const Duration(seconds: 5));

      expect(provider.timerState, TimerState.running);
      expect(provider.elapsedSeconds, 5);
      expect(provider.progress, 0);
      expect(provider.formattedTime, '00:05');

      provider.completeCurrentInterval();
      async.flushMicrotasks();

      expect(provider.timerState, TimerState.completed);
      expect(provider.elapsedSeconds, 5);
    });
  });

  test('tabata accumulates work and rest totals across automatic transitions',
      () {
    final provider = WorkoutProvider(
      syncService: SyncService.test(
        storage: InMemoryOfflineStorageService(),
        hasSupabaseConfig: () => false,
      ),
    );
    provider.setManualTimer(
      type: WorkoutType.tabata,
      workSeconds: 2,
      restSeconds: 1,
      rounds: 2,
      hasCountdown: false,
    );

    fakeAsync((async) {
      provider.startTimer();
      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();

      expect(provider.timerState, TimerState.completed);
      expect(provider.totalWorkSeconds, 4);
      expect(provider.totalRestSeconds, 1);
      expect(provider.currentWorkRound, 2);
      expect(provider.currentRestRound, 1);
      expect(provider.formattedTotalWorkTime, '00:04');
      expect(provider.formattedTotalRestTime, '00:01');
    });
  });

  test('completed session duration excludes countdown time', () {
    final storage = InMemoryOfflineStorageService();
    final provider = WorkoutProvider(
      syncService: SyncService.test(
        storage: storage,
        hasSupabaseConfig: () => false,
      ),
    );
    provider.setManualTimer(
      type: WorkoutType.amrap,
      totalSeconds: 2,
      hasCountdown: true,
      countdownSeconds: 1,
    );

    fakeAsync((async) {
      provider.startTimer();
      async.elapse(const Duration(seconds: 1));
      expect(storage.sessions, isEmpty);

      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
    });

    final session = storage.sessions.values.single;
    expect(session.status, SessionStatus.completed);
    expect(session.durationSeconds, 2);
    expect(session.workSeconds, 2);
  });

  test('completed sessions link back to saved workouts loaded from library',
      () {
    final storage = InMemoryOfflineStorageService();
    final provider = WorkoutProvider(
      syncService: SyncService.test(
        storage: storage,
        hasSupabaseConfig: () => false,
      ),
    );
    final workout = _buildWorkout(id: 'saved-3', name: 'Annie').copyWith(
      timerConfig: _buildWorkout(id: 'saved-3', name: 'Annie')
          .timerConfig
          .copyWith(hasCountdown: false),
    );
    provider.setWorkout(workout, fromSavedWorkoutId: workout.id);

    fakeAsync((async) {
      provider.startTimer();
      async.elapse(const Duration(seconds: 60));
      async.flushMicrotasks();
    });

    expect(storage.sessions.values.single.workoutId, 'saved-3');
  });

  test('abandonSession saves abandoned status and resets timer state',
      () async {
    final storage = InMemoryOfflineStorageService();
    final provider = WorkoutProvider(
      syncService: SyncService.test(
        storage: storage,
        hasSupabaseConfig: () => false,
      ),
    );
    provider.setManualTimer(
      type: WorkoutType.amrap,
      totalSeconds: 10,
      hasCountdown: false,
    );

    fakeAsync((async) {
      provider.startTimer();
      async.elapse(const Duration(seconds: 2));
      provider.abandonSession();
      async.flushMicrotasks();
    });

    final session = storage.sessions.values.single;
    expect(session.status, SessionStatus.abandoned);
    expect(session.durationSeconds, 2);
    expect(provider.timerState, TimerState.idle);
    expect(provider.elapsedSeconds, 0);
    expect(provider.counter, 0);
  });

  test('saveWorkout does not link current workout when sync stays local',
      () async {
    final storage = InMemoryOfflineStorageService();
    final provider = WorkoutProvider(
      syncService: SyncService.test(
        storage: storage,
        hasSupabaseConfig: () => true,
        initialOnline: false,
      ),
    );
    final workout = _buildWorkout(id: 'local-only', name: 'Murph');
    provider.setWorkout(workout);

    final synced = await provider.saveWorkout(workout);

    expect(synced, isFalse);
    expect(provider.loadedFromWorkoutId, isNull);
  });

  test('saveWorkout rethrows sync failures from the underlying service',
      () async {
    final provider = WorkoutProvider(
      syncService: SyncService.test(
        storage: ThrowingOfflineStorageService(),
        hasSupabaseConfig: () => false,
      ),
    );
    final workout = _buildWorkout(id: 'broken', name: 'Broken');
    provider.setWorkout(workout);

    await _runWithSuppressedDebugPrint(
      () => expectLater(
        provider.saveWorkout(workout),
        throwsA(isA<StateError>()),
      ),
    );
  });

  test('parseWorkout rejects empty input before calling the API', () async {
    final provider = WorkoutProvider(
      syncService: SyncService.test(
        storage: InMemoryOfflineStorageService(),
        hasSupabaseConfig: () => false,
      ),
    );
    provider.setWorkoutInput('   ');

    await provider.parseWorkout();

    expect(provider.parseError, 'Please enter a workout description');
    expect(provider.currentWorkout, isNull);
  });

  test('parseWorkout rejects invalid timer configurations from the API',
      () async {
    final provider = WorkoutProvider(
      apiService: ApiService.test(
        parseWorkoutOverride: (_) async => {
          'name': 'Broken timer',
          'workout_type': 'amrap',
          'timer_config': {
            'intervals': [
              {'duration': 3, 'type': 'work'},
            ],
          },
        },
      ),
      syncService: SyncService.test(
        storage: InMemoryOfflineStorageService(),
        hasSupabaseConfig: () => false,
      ),
    );
    provider.setWorkoutInput('AMRAP 3 seconds');

    await provider.parseWorkout();

    expect(
      provider.parseError,
      'Invalid timer configuration. Please try again.',
    );
    expect(provider.currentWorkout, isNull);
    expect(provider.isParsing, isFalse);
  });
}
