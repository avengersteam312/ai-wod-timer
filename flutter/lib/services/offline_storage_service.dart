import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/workout.dart';
import '../models/workout_session.dart';

class OfflineStorageService {
  static final OfflineStorageService _instance =
      OfflineStorageService._internal();
  factory OfflineStorageService() => _instance;
  OfflineStorageService._internal();

  static const String _workoutsBox = 'workouts';
  static const String _sessionsBox = 'sessions';
  static const String _syncQueueBox = 'sync_queue';
  static const String _preferencesBox = 'preferences';

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    await Hive.initFlutter();

    // Open boxes
    await Hive.openBox<String>(_workoutsBox);
    await Hive.openBox<String>(_sessionsBox);
    await Hive.openBox<Map>(_syncQueueBox);
    await Hive.openBox<dynamic>(_preferencesBox);

    _isInitialized = true;
  }

  // Workouts
  Future<void> saveWorkout(Workout workout) async {
    final box = Hive.box<String>(_workoutsBox);
    await box.put(workout.id, jsonEncode(workout.toJson()));
  }

  Future<void> saveWorkouts(List<Workout> workouts) async {
    final box = Hive.box<String>(_workoutsBox);
    final map = <String, String>{};
    for (final workout in workouts) {
      map[workout.id] = jsonEncode(workout.toJson());
    }
    await box.putAll(map);
  }

  Future<List<Workout>> getWorkouts(String userId) async {
    final box = Hive.box<String>(_workoutsBox);
    final workouts = <Workout>[];

    for (final json in box.values) {
      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        final workout = Workout.fromJson(data);
        if (workout.userId == userId) {
          workouts.add(workout);
        }
      } catch (e) {
        debugPrint('Error parsing workout: $e');
      }
    }

    // Sort by created date descending
    workouts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return workouts;
  }

  Future<Workout?> getWorkout(String id) async {
    final box = Hive.box<String>(_workoutsBox);
    final json = box.get(id);
    if (json == null) return null;

    try {
      return Workout.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error parsing workout: $e');
      return null;
    }
  }

  Future<void> deleteWorkout(String id) async {
    final box = Hive.box<String>(_workoutsBox);
    await box.delete(id);
  }

  Future<void> clearWorkouts() async {
    final box = Hive.box<String>(_workoutsBox);
    await box.clear();
  }

  // Sessions
  Future<void> saveSession(WorkoutSession session) async {
    final box = Hive.box<String>(_sessionsBox);
    await box.put(session.id, jsonEncode(session.toJson()));
  }

  Future<void> saveSessions(List<WorkoutSession> sessions) async {
    final box = Hive.box<String>(_sessionsBox);
    final map = <String, String>{};
    for (final session in sessions) {
      map[session.id] = jsonEncode(session.toJson());
    }
    await box.putAll(map);
  }

  Future<List<WorkoutSession>> getSessions(String userId) async {
    final box = Hive.box<String>(_sessionsBox);
    final sessions = <WorkoutSession>[];

    for (final json in box.values) {
      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        final session = WorkoutSession.fromJson(data);
        if (session.userId == userId) {
          sessions.add(session);
        }
      } catch (e) {
        debugPrint('Error parsing session: $e');
      }
    }

    // Sort by started date descending
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  Future<WorkoutSession?> getSession(String id) async {
    final box = Hive.box<String>(_sessionsBox);
    final json = box.get(id);
    if (json == null) return null;

    try {
      return WorkoutSession.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Error parsing session: $e');
      return null;
    }
  }

  Future<void> deleteSession(String id) async {
    final box = Hive.box<String>(_sessionsBox);
    await box.delete(id);
  }

  Future<void> clearSessions() async {
    final box = Hive.box<String>(_sessionsBox);
    await box.clear();
  }

  // Sync Queue
  Future<void> addToSyncQueue(SyncOperation operation) async {
    final box = Hive.box<Map>(_syncQueueBox);
    await box.put(operation.id, operation.toMap());
  }

  Future<List<SyncOperation>> getSyncQueue() async {
    final box = Hive.box<Map>(_syncQueueBox);
    final operations = <SyncOperation>[];

    for (final entry in box.toMap().entries) {
      try {
        operations.add(SyncOperation.fromMap(
          entry.key,
          Map<String, dynamic>.from(entry.value),
        ));
      } catch (e) {
        debugPrint('Error parsing sync operation: $e');
      }
    }

    // Sort by timestamp
    operations.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return operations;
  }

  Future<void> removeFromSyncQueue(String id) async {
    final box = Hive.box<Map>(_syncQueueBox);
    await box.delete(id);
  }

  Future<void> clearSyncQueue() async {
    final box = Hive.box<Map>(_syncQueueBox);
    await box.clear();
  }

  // Preferences
  Future<void> setPreference(String key, dynamic value) async {
    final box = Hive.box<dynamic>(_preferencesBox);
    await box.put(key, value);
  }

  T? getPreference<T>(String key, {T? defaultValue}) {
    final box = Hive.box<dynamic>(_preferencesBox);
    return box.get(key, defaultValue: defaultValue) as T?;
  }

  Future<void> removePreference(String key) async {
    final box = Hive.box<dynamic>(_preferencesBox);
    await box.delete(key);
  }

  // Clear all data
  Future<void> clearAll() async {
    await clearWorkouts();
    await clearSessions();
    await clearSyncQueue();
    final prefBox = Hive.box<dynamic>(_preferencesBox);
    await prefBox.clear();
  }
}

enum SyncOperationType {
  create,
  update,
  delete,
}

enum SyncEntityType {
  workout,
  session,
}

class SyncOperation {
  final String id;
  final SyncOperationType type;
  final SyncEntityType entity;
  final String entityId;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  SyncOperation({
    required this.id,
    required this.type,
    required this.entity,
    required this.entityId,
    this.data,
    required this.timestamp,
  });

  factory SyncOperation.fromMap(String id, Map<String, dynamic> map) {
    return SyncOperation(
      id: id,
      type: SyncOperationType.values[map['type'] as int],
      entity: SyncEntityType.values[map['entity'] as int],
      entityId: map['entity_id'] as String,
      data: map['data'] as Map<String, dynamic>?,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.index,
      'entity': entity.index,
      'entity_id': entityId,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
