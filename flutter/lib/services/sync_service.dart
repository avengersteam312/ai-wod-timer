import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'offline_storage_service.dart';
import '../config/app_config.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal({
    OfflineStorageService? storage,
    Connectivity? connectivity,
    bool Function()? hasSupabaseConfig,
    Future<List<Workout>> Function(String userId)? fetchRemoteWorkouts,
    Future<List<WorkoutSession>> Function(String userId)? fetchRemoteSessions,
    Future<void> Function(Map<String, dynamic> workout)? upsertRemoteWorkout,
    Future<void> Function(String workoutId)? deleteRemoteWorkout,
    Future<void> Function(Map<String, dynamic> session)? upsertRemoteSession,
    Future<void> Function(String sessionId)? deleteRemoteSession,
    bool initialOnline = true,
  })  : _storage = storage ?? OfflineStorageService(),
        _connectivity = connectivity ?? Connectivity(),
        _hasSupabaseConfig = hasSupabaseConfig ?? _defaultHasSupabaseConfig,
        _fetchRemoteWorkouts = fetchRemoteWorkouts,
        _fetchRemoteSessions = fetchRemoteSessions,
        _upsertRemoteWorkout = upsertRemoteWorkout,
        _deleteRemoteWorkout = deleteRemoteWorkout,
        _upsertRemoteSession = upsertRemoteSession,
        _deleteRemoteSession = deleteRemoteSession {
    _isOnline = initialOnline;
  }
  SyncService.test({
    OfflineStorageService? storage,
    Connectivity? connectivity,
    bool Function()? hasSupabaseConfig,
    Future<List<Workout>> Function(String userId)? fetchRemoteWorkouts,
    Future<List<WorkoutSession>> Function(String userId)? fetchRemoteSessions,
    Future<void> Function(Map<String, dynamic> workout)? upsertRemoteWorkout,
    Future<void> Function(String workoutId)? deleteRemoteWorkout,
    Future<void> Function(Map<String, dynamic> session)? upsertRemoteSession,
    Future<void> Function(String sessionId)? deleteRemoteSession,
    bool initialOnline = true,
  }) : this._internal(
          storage: storage ?? OfflineStorageService.test(),
          connectivity: connectivity,
          hasSupabaseConfig: hasSupabaseConfig,
          fetchRemoteWorkouts: fetchRemoteWorkouts,
          fetchRemoteSessions: fetchRemoteSessions,
          upsertRemoteWorkout: upsertRemoteWorkout,
          deleteRemoteWorkout: deleteRemoteWorkout,
          upsertRemoteSession: upsertRemoteSession,
          deleteRemoteSession: deleteRemoteSession,
          initialOnline: initialOnline,
        );

  final OfflineStorageService _storage;
  final Connectivity _connectivity;
  final bool Function() _hasSupabaseConfig;
  final Future<List<Workout>> Function(String userId)? _fetchRemoteWorkouts;
  final Future<List<WorkoutSession>> Function(String userId)?
      _fetchRemoteSessions;
  final Future<void> Function(Map<String, dynamic> workout)?
      _upsertRemoteWorkout;
  final Future<void> Function(String workoutId)? _deleteRemoteWorkout;
  final Future<void> Function(Map<String, dynamic> session)?
      _upsertRemoteSession;
  final Future<void> Function(String sessionId)? _deleteRemoteSession;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isSyncing = false;

  final _onlineController = StreamController<bool>.broadcast();
  Stream<bool> get onlineStream => _onlineController.stream;
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  SupabaseClient get _client => Supabase.instance.client;
  static bool _defaultHasSupabaseConfig() => AppConfig.hasSupabaseConfig;

  Future<void> init() async {
    await _storage.init();

    // Check initial connectivity
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    _onlineController.add(_isOnline);

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) async {
        final wasOnline = _isOnline;
        _isOnline = results.any((r) => r != ConnectivityResult.none);

        if (_isOnline != wasOnline) {
          _onlineController.add(_isOnline);

          // Process sync queue when coming back online
          if (_isOnline) {
            await processSyncQueue();
          }
        }
      },
    );
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _onlineController.close();
  }

  // Sync Queue Processing
  Future<void> processSyncQueue() async {
    if (!_isOnline || _isSyncing || !_hasSupabaseConfig()) return;

    _isSyncing = true;

    try {
      final queue = await _storage.getSyncQueue();

      for (final operation in queue) {
        try {
          await _processSyncOperation(operation);
          await _storage.removeFromSyncQueue(operation.id);
        } catch (_) {
          // Keep in queue for retry
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _processSyncOperation(SyncOperation operation) async {
    switch (operation.entity) {
      case SyncEntityType.workout:
        await _syncWorkoutOperation(operation);
        break;
      case SyncEntityType.session:
        await _syncSessionOperation(operation);
        break;
    }
  }

  Future<void> _syncWorkoutOperation(SyncOperation operation) async {
    switch (operation.type) {
      case SyncOperationType.create:
      case SyncOperationType.update:
        if (operation.data != null) {
          await _upsertWorkout(operation.data!);
        }
        break;
      case SyncOperationType.delete:
        await _deleteWorkoutRemote(operation.entityId);
        break;
    }
  }

  Future<void> _syncSessionOperation(SyncOperation operation) async {
    switch (operation.type) {
      case SyncOperationType.create:
      case SyncOperationType.update:
        if (operation.data != null) {
          await _upsertSession(operation.data!);
        }
        break;
      case SyncOperationType.delete:
        await _deleteSessionRemote(operation.entityId);
        break;
    }
  }

  Future<List<Workout>> _getRemoteWorkouts(String userId) async {
    if (_fetchRemoteWorkouts != null) {
      return _fetchRemoteWorkouts!(userId);
    }

    final response = await _client
        .from('workouts')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Workout.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<WorkoutSession>> _getRemoteSessions(String userId) async {
    if (_fetchRemoteSessions != null) {
      return _fetchRemoteSessions!(userId);
    }

    final response = await _client
        .from('workout_sessions')
        .select()
        .eq('user_id', userId)
        .order('started_at', ascending: false);

    return (response as List)
        .map((json) => WorkoutSession.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> _upsertWorkout(Map<String, dynamic> workout) async {
    if (_upsertRemoteWorkout != null) {
      await _upsertRemoteWorkout!(workout);
      return;
    }
    await _client.from('workouts').upsert(workout);
  }

  Future<void> _deleteWorkoutRemote(String workoutId) async {
    if (_deleteRemoteWorkout != null) {
      await _deleteRemoteWorkout!(workoutId);
      return;
    }
    await _client.from('workouts').delete().eq('id', workoutId);
  }

  Future<void> _upsertSession(Map<String, dynamic> session) async {
    if (_upsertRemoteSession != null) {
      await _upsertRemoteSession!(session);
      return;
    }
    await _client.from('workout_sessions').upsert(session);
  }

  Future<void> _deleteSessionRemote(String sessionId) async {
    if (_deleteRemoteSession != null) {
      await _deleteRemoteSession!(sessionId);
      return;
    }
    await _client.from('workout_sessions').delete().eq('id', sessionId);
  }

  // Workout Sync Methods
  Future<List<Workout>> getWorkouts(String userId) async {
    // Try to get from remote first if online and Supabase is configured
    // Skip for anonymous users (not a valid UUID)
    if (_isOnline && _hasSupabaseConfig() && userId != 'anonymous') {
      try {
        final workouts = await _getRemoteWorkouts(userId);

        // Cache locally
        await _storage.saveWorkouts(workouts);

        return workouts;
      } catch (_) {
      }
    }

    // Fall back to local storage
    return _storage.getWorkouts(userId);
  }

  /// Saves the workout locally and, when online, to Supabase.
  /// Returns true only when the workout was successfully written to the remote
  /// (so it is safe to link sessions to this workout_id). Returns false when
  /// offline or when remote write failed (workout is queued for later sync).
  Future<bool> saveWorkout(Workout workout) async {
    // Always save locally first
    await _storage.saveWorkout(workout);

    if (_isOnline && _hasSupabaseConfig()) {
      try {
        await _upsertWorkout(workout.toJson());
        return true;
      } catch (_) {
        await _queueWorkoutSync(workout, SyncOperationType.create);
        return false;
      }
    }
    if (_hasSupabaseConfig()) {
      await _queueWorkoutSync(workout, SyncOperationType.create);
    }
    return false;
  }

  Future<void> updateWorkout(Workout workout) async {
    await _storage.saveWorkout(workout);

    if (_isOnline && _hasSupabaseConfig()) {
      try {
        // Use upsert so a missing row (e.g. after offline create) is inserted instead of no-op
        await _upsertWorkout(workout.toJson());
      } catch (_) {
        await _queueWorkoutSync(workout, SyncOperationType.update);
      }
    } else if (_hasSupabaseConfig()) {
      await _queueWorkoutSync(workout, SyncOperationType.update);
    }
  }

  Future<void> deleteWorkout(String id) async {
    await _storage.deleteWorkout(id);

    if (_isOnline && _hasSupabaseConfig()) {
      try {
        await _deleteWorkoutRemote(id);
      } catch (_) {
        await _queueWorkoutDelete(id, SyncEntityType.workout);
      }
    } else if (_hasSupabaseConfig()) {
      await _queueWorkoutDelete(id, SyncEntityType.workout);
    }
  }

  Future<void> _queueWorkoutSync(
    Workout workout,
    SyncOperationType type,
  ) async {
    final operation = SyncOperation(
      id: '${workout.id}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      entity: SyncEntityType.workout,
      entityId: workout.id,
      data: workout.toJson(),
      timestamp: DateTime.now(),
    );
    await _storage.addToSyncQueue(operation);
  }

  Future<void> _queueWorkoutDelete(String id, SyncEntityType entity) async {
    final operation = SyncOperation(
      id: '${id}_delete_${DateTime.now().millisecondsSinceEpoch}',
      type: SyncOperationType.delete,
      entity: entity,
      entityId: id,
      timestamp: DateTime.now(),
    );
    await _storage.addToSyncQueue(operation);
  }

  // Session Sync Methods
  Future<List<WorkoutSession>> getSessions(String userId) async {
    // Skip remote fetch for anonymous users (not a valid UUID)
    if (_isOnline && _hasSupabaseConfig() && userId != 'anonymous') {
      try {
        final sessions = await _getRemoteSessions(userId);

        await _storage.saveSessions(sessions);

        return sessions;
      } catch (_) {
      }
    }

    return _storage.getSessions(userId);
  }

  Future<void> saveSession(WorkoutSession session) async {
    await _storage.saveSession(session);

    if (_isOnline && _hasSupabaseConfig()) {
      try {
        await _upsertSession(session.toJson());
      } catch (_) {
        await _queueSessionSync(session, SyncOperationType.create);
      }
    } else if (_hasSupabaseConfig()) {
      await _queueSessionSync(session, SyncOperationType.create);
    }
  }

  Future<void> updateSession(WorkoutSession session) async {
    await _storage.saveSession(session);

    if (_isOnline && _hasSupabaseConfig()) {
      try {
        // Use upsert so a missing row (e.g. after offline create) is inserted instead of no-op
        await _upsertSession(session.toJson());
      } catch (_) {
        await _queueSessionSync(session, SyncOperationType.update);
      }
    } else if (_hasSupabaseConfig()) {
      await _queueSessionSync(session, SyncOperationType.update);
    }
  }

  Future<void> _queueSessionSync(
    WorkoutSession session,
    SyncOperationType type,
  ) async {
    final operation = SyncOperation(
      id: '${session.id}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      entity: SyncEntityType.session,
      entityId: session.id,
      data: session.toJson(),
      timestamp: DateTime.now(),
    );
    await _storage.addToSyncQueue(operation);
  }

  Future<void> deleteSession(String id) async {
    await _storage.deleteSession(id);

    if (_isOnline && _hasSupabaseConfig()) {
      try {
        await _deleteSessionRemote(id);
      } catch (_) {
        await _queueSessionDelete(id);
      }
    } else if (_hasSupabaseConfig()) {
      await _queueSessionDelete(id);
    }
  }

  Future<void> _queueSessionDelete(String id) async {
    final operation = SyncOperation(
      id: '${id}_delete_${DateTime.now().millisecondsSinceEpoch}',
      type: SyncOperationType.delete,
      entity: SyncEntityType.session,
      entityId: id,
      timestamp: DateTime.now(),
    );
    await _storage.addToSyncQueue(operation);
  }

  // Full Sync
  Future<void> fullSync(String userId) async {
    if (!_isOnline || !_hasSupabaseConfig()) return;

    try {
      // Process any pending operations first
      await processSyncQueue();

      // Fetch all data from remote
      await getWorkouts(userId);
      await getSessions(userId);
    } catch (_) {
    }
  }
}
