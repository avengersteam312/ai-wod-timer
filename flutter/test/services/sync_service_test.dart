import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:ai_wod_timer/models/workout.dart';
import 'package:ai_wod_timer/models/workout_session.dart';
import 'package:ai_wod_timer/services/offline_storage_service.dart';
import 'package:ai_wod_timer/services/sync_service.dart';

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
  Future<void> saveSessions(List<WorkoutSession> values) async {
    for (final session in values) {
      sessions[session.id] = session;
    }
  }

  @override
  Future<List<WorkoutSession>> getSessions(String userId) async {
    final values = sessions.values.where((s) => s.userId == userId).toList();
    values.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return values;
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

Workout _buildWorkout({
  required String id,
  required String name,
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
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

WorkoutSession _buildSession(String id) {
  return WorkoutSession(
    id: id,
    userId: 'user-123',
    workoutName: 'Fran',
    workoutType: 'emom',
    workoutSnapshot: const {},
    status: SessionStatus.completed,
    startedAt: DateTime.utc(2026, 1, 1),
  );
}

class FakeConnectivityPlatform extends ConnectivityPlatform
    with MockPlatformInterfaceMixin {
  FakeConnectivityPlatform(this.currentResult);

  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();
  ConnectivityResult currentResult;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [currentResult];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  void emit(ConnectivityResult result) {
    currentResult = result;
    _controller.add([result]);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectivityPlatform originalConnectivityPlatform;

  setUpAll(() {
    dotenv.loadFromString(
      envString: '''
API_BASE_URL=http://localhost:8000
AUTH_ENABLED=false
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=
''',
    );
    originalConnectivityPlatform = ConnectivityPlatform.instance;
  });

  tearDown(() {
    ConnectivityPlatform.instance = originalConnectivityPlatform;
  });

  test('getWorkouts returns remote data and caches it locally', () async {
    final storage = InMemoryOfflineStorageService();
    final remoteWorkout = _buildWorkout(id: 'remote-1', name: 'Murph');
    final service = SyncService.test(
      storage: storage,
      hasSupabaseConfig: () => true,
      fetchRemoteWorkouts: (_) async => [remoteWorkout],
    );

    final workouts = await service.getWorkouts('user-123');

    expect(workouts.map((w) => w.id), ['remote-1']);
    expect(storage.workouts['remote-1']?.name, 'Murph');
  });

  test('saveWorkout offline queues create operation and returns false',
      () async {
    final storage = InMemoryOfflineStorageService();
    final service = SyncService.test(
      storage: storage,
      hasSupabaseConfig: () => true,
      initialOnline: false,
    );
    final workout = _buildWorkout(id: 'offline-1', name: 'Cindy');

    final synced = await service.saveWorkout(workout);

    expect(synced, isFalse);
    expect(storage.workouts['offline-1']?.name, 'Cindy');
    expect(storage.queue.values.single.type, SyncOperationType.create);
    expect(storage.queue.values.single.entity, SyncEntityType.workout);
  });

  test('updateWorkout queues an update when remote write fails', () async {
    final storage = InMemoryOfflineStorageService();
    final service = SyncService.test(
      storage: storage,
      hasSupabaseConfig: () => true,
      upsertRemoteWorkout: (_) async => throw Exception('remote failed'),
    );
    final workout = _buildWorkout(id: 'update-1', name: 'Fran');

    await service.updateWorkout(workout);

    expect(storage.workouts['update-1'], isNotNull);
    expect(storage.queue.values.single.type, SyncOperationType.update);
  });

  test('deleteWorkout offline removes local workout and queues delete',
      () async {
    final storage = InMemoryOfflineStorageService();
    final workout = _buildWorkout(id: 'delete-1', name: 'Annie');
    await storage.saveWorkout(workout);
    final service = SyncService.test(
      storage: storage,
      hasSupabaseConfig: () => true,
      initialOnline: false,
    );

    await service.deleteWorkout('delete-1');

    expect(storage.workouts.containsKey('delete-1'), isFalse);
    expect(storage.queue.values.single.type, SyncOperationType.delete);
  });

  test('processSyncQueue removes successful operations and keeps failures',
      () async {
    final storage = InMemoryOfflineStorageService();
    final successfulWorkout = _buildWorkout(id: 'ok-1', name: 'Fran');
    final failingSession = _buildSession('session-1');
    await storage.addToSyncQueue(
      SyncOperation(
        id: 'q1',
        type: SyncOperationType.create,
        entity: SyncEntityType.workout,
        entityId: successfulWorkout.id,
        data: successfulWorkout.toJson(),
        timestamp: DateTime.utc(2026, 1, 1, 0, 0, 1),
      ),
    );
    await storage.addToSyncQueue(
      SyncOperation(
        id: 'q2',
        type: SyncOperationType.create,
        entity: SyncEntityType.session,
        entityId: failingSession.id,
        data: failingSession.toJson(),
        timestamp: DateTime.utc(2026, 1, 1, 0, 0, 2),
      ),
    );

    final processedWorkouts = <String>[];
    final service = SyncService.test(
      storage: storage,
      hasSupabaseConfig: () => true,
      upsertRemoteWorkout: (payload) async {
        processedWorkouts.add(payload['id'] as String);
      },
      upsertRemoteSession: (_) async => throw Exception('session failed'),
    );

    await service.processSyncQueue();

    expect(processedWorkouts, ['ok-1']);
    expect(storage.queue.keys, ['q2']);
    expect(service.isSyncing, isFalse);
  });

  test('getWorkouts falls back to local data when remote fetch fails',
      () async {
    final storage = InMemoryOfflineStorageService();
    await storage.saveWorkout(_buildWorkout(id: 'local-1', name: 'Local Fran'));
    final service = SyncService.test(
      storage: storage,
      hasSupabaseConfig: () => true,
      fetchRemoteWorkouts: (_) async => throw Exception('boom'),
    );

    final workouts = await service.getWorkouts('user-123');

    expect(workouts.map((w) => w.id), ['local-1']);
  });

  test('getWorkouts skips remote fetch for anonymous users', () async {
    final storage = InMemoryOfflineStorageService();
    var fetchCalls = 0;
    final service = SyncService.test(
      storage: storage,
      hasSupabaseConfig: () => true,
      fetchRemoteWorkouts: (_) async {
        fetchCalls++;
        return [];
      },
    );

    await service.getWorkouts('anonymous');

    expect(fetchCalls, 0);
  });

  test('saveWorkout returns true and does not queue when remote save succeeds',
      () async {
    final storage = InMemoryOfflineStorageService();
    final service = SyncService.test(
      storage: storage,
      hasSupabaseConfig: () => true,
      upsertRemoteWorkout: (_) async {},
    );

    final synced = await service.saveWorkout(
      _buildWorkout(id: 'remote-save', name: 'Helen'),
    );

    expect(synced, isTrue);
    expect(storage.queue, isEmpty);
  });

  test('deleteWorkout queues delete when remote removal fails', () async {
    final storage = InMemoryOfflineStorageService();
    await storage.saveWorkout(_buildWorkout(id: 'remote-delete', name: 'DT'));
    final service = SyncService.test(
      storage: storage,
      hasSupabaseConfig: () => true,
      deleteRemoteWorkout: (_) async => throw Exception('nope'),
    );

    await service.deleteWorkout('remote-delete');

    expect(storage.workouts.containsKey('remote-delete'), isFalse);
    expect(storage.queue.values.single.type, SyncOperationType.delete);
    expect(storage.queue.values.single.entity, SyncEntityType.workout);
  });

  test('getSessions returns remote data and caches it locally', () async {
    final storage = InMemoryOfflineStorageService();
    final remoteSession = _buildSession('session-remote');
    final service = SyncService.test(
      storage: storage,
      hasSupabaseConfig: () => true,
      fetchRemoteSessions: (_) async => [remoteSession],
    );

    final sessions = await service.getSessions('user-123');

    expect(sessions.map((s) => s.id), ['session-remote']);
    expect(storage.sessions['session-remote']?.workoutName, 'Fran');
  });

  test('getSessions falls back to local data when remote fetch fails',
      () async {
    final storage = InMemoryOfflineStorageService();
    await storage.saveSession(_buildSession('local-session'));
    final service = SyncService.test(
      storage: storage,
      hasSupabaseConfig: () => true,
      fetchRemoteSessions: (_) async => throw Exception('boom'),
    );

    final sessions = await service.getSessions('user-123');

    expect(sessions.map((s) => s.id), ['local-session']);
  });

  test('saveSession offline queues a create operation', () async {
    final storage = InMemoryOfflineStorageService();
    final session = _buildSession('offline-session');
    final service = SyncService.test(
      storage: storage,
      hasSupabaseConfig: () => true,
      initialOnline: false,
    );

    await service.saveSession(session);

    expect(storage.sessions['offline-session'], isNotNull);
    expect(storage.queue.values.single.type, SyncOperationType.create);
    expect(storage.queue.values.single.entity, SyncEntityType.session);
  });

  test('updateSession queues an update when remote write fails', () async {
    final storage = InMemoryOfflineStorageService();
    final session = _buildSession('update-session');
    final service = SyncService.test(
      storage: storage,
      hasSupabaseConfig: () => true,
      upsertRemoteSession: (_) async => throw Exception('nope'),
    );

    await service.updateSession(session);

    expect(storage.sessions['update-session'], isNotNull);
    expect(storage.queue.values.single.type, SyncOperationType.update);
    expect(storage.queue.values.single.entity, SyncEntityType.session);
  });

  test('deleteSession queues delete when remote removal fails', () async {
    final storage = InMemoryOfflineStorageService();
    await storage.saveSession(_buildSession('delete-session'));
    final service = SyncService.test(
      storage: storage,
      hasSupabaseConfig: () => true,
      deleteRemoteSession: (_) async => throw Exception('nope'),
    );

    await service.deleteSession('delete-session');

    expect(storage.sessions.containsKey('delete-session'), isFalse);
    expect(storage.queue.values.single.type, SyncOperationType.delete);
    expect(storage.queue.values.single.entity, SyncEntityType.session);
  });

  test('processSyncQueue returns early while offline', () async {
    final storage = InMemoryOfflineStorageService();
    await storage.addToSyncQueue(
      SyncOperation(
        id: 'offline-queue',
        type: SyncOperationType.create,
        entity: SyncEntityType.workout,
        entityId: 'w1',
        data: _buildWorkout(id: 'w1', name: 'Fran').toJson(),
        timestamp: DateTime.utc(2026, 1, 1),
      ),
    );
    var processed = false;
    final service = SyncService.test(
      storage: storage,
      hasSupabaseConfig: () => true,
      initialOnline: false,
      upsertRemoteWorkout: (_) async {
        processed = true;
      },
    );

    await service.processSyncQueue();

    expect(processed, isFalse);
    expect(storage.queue.keys, ['offline-queue']);
  });

  test('init emits online changes and syncs queued work on reconnect',
      () async {
    final fakePlatform = FakeConnectivityPlatform(ConnectivityResult.none);
    ConnectivityPlatform.instance = fakePlatform;
    final storage = InMemoryOfflineStorageService();
    await storage.addToSyncQueue(
      SyncOperation(
        id: 'queued-create',
        type: SyncOperationType.create,
        entity: SyncEntityType.workout,
        entityId: 'queued-w1',
        data: _buildWorkout(id: 'queued-w1', name: 'Queued').toJson(),
        timestamp: DateTime.utc(2026, 1, 1),
      ),
    );
    final onlineStates = <bool>[];
    final processed = <String>[];
    final service = SyncService.test(
      storage: storage,
      connectivity: Connectivity(),
      hasSupabaseConfig: () => true,
      upsertRemoteWorkout: (payload) async {
        processed.add(payload['id'] as String);
      },
    );
    final subscription = service.onlineStream.listen(onlineStates.add);

    await service.init();
    fakePlatform.emit(ConnectivityResult.wifi);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(service.isOnline, isTrue);
    expect(onlineStates, [false, true]);
    expect(processed, ['queued-w1']);
    expect(storage.queue, isEmpty);

    await subscription.cancel();
    service.dispose();
    await fakePlatform.dispose();
  });

  test('fullSync processes queue before fetching remote workouts and sessions',
      () async {
    final storage = InMemoryOfflineStorageService();
    await storage.addToSyncQueue(
      SyncOperation(
        id: 'queued-sync',
        type: SyncOperationType.create,
        entity: SyncEntityType.workout,
        entityId: 'queued-workout',
        data: _buildWorkout(id: 'queued-workout', name: 'Queue').toJson(),
        timestamp: DateTime.utc(2026, 1, 1),
      ),
    );
    final events = <String>[];
    final service = SyncService.test(
      storage: storage,
      hasSupabaseConfig: () => true,
      upsertRemoteWorkout: (_) async => events.add('process-queue'),
      fetchRemoteWorkouts: (_) async {
        events.add('fetch-workouts');
        return [];
      },
      fetchRemoteSessions: (_) async {
        events.add('fetch-sessions');
        return [];
      },
    );

    await service.fullSync('user-123');

    expect(
      events,
      ['process-queue', 'fetch-workouts', 'fetch-sessions'],
    );
    expect(storage.queue, isEmpty);
  });
}
