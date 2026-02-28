import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'offline_storage_service.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final OfflineStorageService _storage = OfflineStorageService();
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = true;
  bool _isSyncing = false;

  final _onlineController = StreamController<bool>.broadcast();
  Stream<bool> get onlineStream => _onlineController.stream;
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> init() async {
    await _storage.init();

    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    _onlineController.add(_isOnline);

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (result) async {
        final wasOnline = _isOnline;
        _isOnline = result != ConnectivityResult.none;

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
    if (!_isOnline || _isSyncing) return;

    _isSyncing = true;

    try {
      final queue = await _storage.getSyncQueue();

      for (final operation in queue) {
        try {
          await _processSyncOperation(operation);
          await _storage.removeFromSyncQueue(operation.id);
        } catch (e) {
          debugPrint('Error processing sync operation: $e');
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
          await _client.from('workouts').upsert(operation.data!);
        }
        break;
      case SyncOperationType.delete:
        await _client
            .from('workouts')
            .delete()
            .eq('id', operation.entityId);
        break;
    }
  }

  Future<void> _syncSessionOperation(SyncOperation operation) async {
    switch (operation.type) {
      case SyncOperationType.create:
      case SyncOperationType.update:
        if (operation.data != null) {
          await _client.from('workout_sessions').upsert(operation.data!);
        }
        break;
      case SyncOperationType.delete:
        await _client
            .from('workout_sessions')
            .delete()
            .eq('id', operation.entityId);
        break;
    }
  }

  // Workout Sync Methods
  Future<List<Workout>> getWorkouts(String userId) async {
    // Try to get from remote first if online
    if (_isOnline) {
      try {
        final response = await _client
            .from('workouts')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        final workouts = (response as List)
            .map((json) => Workout.fromJson(json as Map<String, dynamic>))
            .toList();

        // Cache locally
        await _storage.saveWorkouts(workouts);

        return workouts;
      } catch (e) {
        debugPrint('Error fetching workouts from remote: $e');
      }
    }

    // Fall back to local storage
    return _storage.getWorkouts(userId);
  }

  Future<void> saveWorkout(Workout workout) async {
    // Always save locally first
    await _storage.saveWorkout(workout);

    if (_isOnline) {
      try {
        await _client.from('workouts').upsert(workout.toJson());
      } catch (e) {
        debugPrint('Error saving workout to remote: $e');
        // Queue for later sync
        await _queueWorkoutSync(workout, SyncOperationType.create);
      }
    } else {
      // Queue for later sync
      await _queueWorkoutSync(workout, SyncOperationType.create);
    }
  }

  Future<void> updateWorkout(Workout workout) async {
    await _storage.saveWorkout(workout);

    if (_isOnline) {
      try {
        await _client.from('workouts').update(workout.toJson()).eq('id', workout.id);
      } catch (e) {
        debugPrint('Error updating workout on remote: $e');
        await _queueWorkoutSync(workout, SyncOperationType.update);
      }
    } else {
      await _queueWorkoutSync(workout, SyncOperationType.update);
    }
  }

  Future<void> deleteWorkout(String id) async {
    await _storage.deleteWorkout(id);

    if (_isOnline) {
      try {
        await _client.from('workouts').delete().eq('id', id);
      } catch (e) {
        debugPrint('Error deleting workout from remote: $e');
        await _queueWorkoutDelete(id, SyncEntityType.workout);
      }
    } else {
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
    if (_isOnline) {
      try {
        final response = await _client
            .from('workout_sessions')
            .select()
            .eq('user_id', userId)
            .order('started_at', ascending: false);

        final sessions = (response as List)
            .map((json) =>
                WorkoutSession.fromJson(json as Map<String, dynamic>))
            .toList();

        await _storage.saveSessions(sessions);

        return sessions;
      } catch (e) {
        debugPrint('Error fetching sessions from remote: $e');
      }
    }

    return _storage.getSessions(userId);
  }

  Future<void> saveSession(WorkoutSession session) async {
    await _storage.saveSession(session);

    if (_isOnline) {
      try {
        await _client.from('workout_sessions').upsert(session.toJson());
      } catch (e) {
        debugPrint('Error saving session to remote: $e');
        await _queueSessionSync(session, SyncOperationType.create);
      }
    } else {
      await _queueSessionSync(session, SyncOperationType.create);
    }
  }

  Future<void> updateSession(WorkoutSession session) async {
    await _storage.saveSession(session);

    if (_isOnline) {
      try {
        await _client
            .from('workout_sessions')
            .update(session.toJson())
            .eq('id', session.id);
      } catch (e) {
        debugPrint('Error updating session on remote: $e');
        await _queueSessionSync(session, SyncOperationType.update);
      }
    } else {
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

  // Full Sync
  Future<void> fullSync(String userId) async {
    if (!_isOnline) return;

    try {
      // Process any pending operations first
      await processSyncQueue();

      // Fetch all data from remote
      await getWorkouts(userId);
      await getSessions(userId);
    } catch (e) {
      debugPrint('Error during full sync: $e');
    }
  }
}
