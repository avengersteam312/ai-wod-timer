/**
 * Offline Mutation Service
 *
 * Provides offline-aware mutation handling for CRUD operations.
 * When offline, mutations are saved locally and queued for sync when online.
 */
import { v4 as uuidv4 } from 'uuid'
import {
  addToSyncQueue,
  saveLocalWorkout,
  updateLocalWorkout,
  deleteLocalWorkout,
  saveLocalSession,
  updateLocalSession,
  saveLocalPreferences,
  type LocalWorkout,
  type LocalSession,
  type LocalPreferences,
  type SyncTable,
  type SyncOperation
} from './offlineDb'
import type { ParsedWorkout } from '@/types/workout'

/**
 * Check if the browser is currently online
 */
export function isOnline(): boolean {
  return typeof navigator !== 'undefined' ? navigator.onLine : true
}

/**
 * Queue a mutation for sync when offline
 */
export async function queueMutation(
  table: SyncTable,
  operation: SyncOperation,
  recordId: string,
  data: Record<string, unknown> | null = null
): Promise<void> {
  await addToSyncQueue(table, operation, recordId, data)
}

// ============================================================================
// Offline Workout Mutations
// ============================================================================

/**
 * Data for creating a workout offline
 */
interface OfflineWorkoutCreate {
  userId: string
  name: string
  workout: ParsedWorkout
}

/**
 * Create a workout locally when offline
 * Returns the locally created workout record
 */
export async function createWorkoutOffline(data: OfflineWorkoutCreate): Promise<LocalWorkout> {
  const now = new Date().toISOString()
  const id = uuidv4()

  const localWorkout: LocalWorkout = {
    id,
    user_id: data.userId,
    name: data.name,
    raw_input: data.workout.raw_text ?? null,
    parsed_config: data.workout,
    is_favorite: false,
    created_at: now,
    updated_at: now
  }

  // Save to local IndexedDB
  await saveLocalWorkout(localWorkout)

  // Queue for sync
  await queueMutation('workouts', 'insert', id, {
    user_id: data.userId,
    name: data.name,
    raw_input: data.workout.raw_text ?? null,
    parsed_config: data.workout,
    is_favorite: false
  })

  return localWorkout
}

/**
 * Update a workout locally when offline
 */
export async function updateWorkoutOffline(
  id: string,
  updates: { name?: string; is_favorite?: boolean }
): Promise<void> {
  // Update in local IndexedDB
  await updateLocalWorkout(id, updates)

  // Queue for sync
  await queueMutation('workouts', 'update', id, updates)
}

/**
 * Delete a workout locally when offline
 */
export async function deleteWorkoutOffline(id: string): Promise<void> {
  // Delete from local IndexedDB
  await deleteLocalWorkout(id)

  // Queue for sync
  await queueMutation('workouts', 'delete', id, null)
}

// ============================================================================
// Offline Session Mutations
// ============================================================================

/**
 * Data for creating a session offline
 */
interface OfflineSessionCreate {
  userId: string
  workout: ParsedWorkout
  workoutId?: string
}

/**
 * Start a session locally when offline
 */
export async function startSessionOffline(data: OfflineSessionCreate): Promise<LocalSession> {
  const now = new Date().toISOString()
  const id = uuidv4()

  const localSession: LocalSession = {
    id,
    user_id: data.userId,
    workout_id: data.workoutId ?? null,
    workout_snapshot: data.workout,
    started_at: now,
    completed_at: null,
    duration_seconds: null,
    status: 'in_progress'
  }

  // Save to local IndexedDB
  await saveLocalSession(localSession)

  // Queue for sync
  await queueMutation('workout_sessions', 'insert', id, {
    user_id: data.userId,
    workout_id: data.workoutId ?? null,
    workout_snapshot: data.workout,
    status: 'in_progress'
  })

  return localSession
}

/**
 * Complete a session locally when offline
 */
export async function completeSessionOffline(
  sessionId: string,
  durationSeconds: number
): Promise<void> {
  const now = new Date().toISOString()

  const updates = {
    status: 'completed' as const,
    completed_at: now,
    duration_seconds: durationSeconds
  }

  // Update in local IndexedDB
  await updateLocalSession(sessionId, updates)

  // Queue for sync
  await queueMutation('workout_sessions', 'update', sessionId, updates)
}

/**
 * Abandon a session locally when offline
 */
export async function abandonSessionOffline(sessionId: string): Promise<void> {
  const now = new Date().toISOString()

  const updates = {
    status: 'abandoned' as const,
    completed_at: now
  }

  // Update in local IndexedDB
  await updateLocalSession(sessionId, updates)

  // Queue for sync
  await queueMutation('workout_sessions', 'update', sessionId, updates)
}

// ============================================================================
// Offline Preferences Mutations
// ============================================================================

/**
 * Update preferences locally when offline
 */
export async function updatePreferencesOffline(
  userId: string,
  currentPreferences: LocalPreferences,
  updates: Partial<Omit<LocalPreferences, 'user_id' | 'updated_at'>>
): Promise<LocalPreferences> {
  const now = new Date().toISOString()

  const updatedPreferences: LocalPreferences = {
    ...currentPreferences,
    ...updates,
    updated_at: now
  }

  // Save to local IndexedDB (upsert)
  await saveLocalPreferences(updatedPreferences)

  // Queue for sync - only include the updates, not full record
  await queueMutation('user_preferences', 'update', userId, updates)

  return updatedPreferences
}

/**
 * Create default preferences locally when offline
 */
export async function createDefaultPreferencesOffline(userId: string): Promise<LocalPreferences> {
  const now = new Date().toISOString()

  const defaultPreferences: LocalPreferences = {
    user_id: userId,
    audio_enabled: true,
    voice_type: 'default',
    theme: 'dark',
    default_rest_seconds: 60,
    countdown_seconds: 10,
    updated_at: now
  }

  // Save to local IndexedDB
  await saveLocalPreferences(defaultPreferences)

  // Queue for sync (insert operation)
  await queueMutation('user_preferences', 'insert', userId, {
    audio_enabled: defaultPreferences.audio_enabled,
    voice_type: defaultPreferences.voice_type,
    theme: defaultPreferences.theme,
    default_rest_seconds: defaultPreferences.default_rest_seconds,
    countdown_seconds: defaultPreferences.countdown_seconds
  })

  return defaultPreferences
}
