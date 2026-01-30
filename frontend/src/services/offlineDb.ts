/**
 * Offline Database Service
 *
 * Provides IndexedDB storage using Dexie for offline-first support.
 * Mirrors Supabase tables locally for offline access and syncing.
 */
import Dexie, { type Table } from 'dexie'
import type { ParsedWorkout } from '@/types/workout'

/**
 * Local workout record matching Supabase workouts table
 */
export interface LocalWorkout {
  id: string
  user_id: string
  name: string
  raw_input: string | null
  parsed_config: ParsedWorkout
  is_favorite: boolean
  created_at: string
  updated_at: string
}

/**
 * Session status values
 */
export type LocalSessionStatus = 'in_progress' | 'completed' | 'abandoned'

/**
 * Local session record matching Supabase workout_sessions table
 */
export interface LocalSession {
  id: string
  user_id: string
  workout_id: string | null
  workout_snapshot: ParsedWorkout
  started_at: string
  completed_at: string | null
  duration_seconds: number | null
  status: LocalSessionStatus
}

/**
 * Local preferences record matching Supabase user_preferences table
 */
export interface LocalPreferences {
  user_id: string
  audio_enabled: boolean
  voice_type: string
  theme: string
  default_rest_seconds: number
  countdown_seconds: number
  updated_at: string
}

/**
 * Sync queue operation types
 */
export type SyncOperation = 'insert' | 'update' | 'delete'

/**
 * Sync queue table names
 */
export type SyncTable = 'workouts' | 'workout_sessions' | 'user_preferences'

/**
 * Sync queue entry for tracking offline mutations
 */
export interface SyncQueueEntry {
  id?: number
  table: SyncTable
  operation: SyncOperation
  record_id: string
  data: Record<string, unknown> | null
  created_at: string
}

/**
 * Dexie database class for offline storage
 */
class OfflineDatabase extends Dexie {
  workouts!: Table<LocalWorkout, string>
  sessions!: Table<LocalSession, string>
  preferences!: Table<LocalPreferences, string>
  syncQueue!: Table<SyncQueueEntry, number>

  constructor() {
    super('ai-wod-timer-offline')

    this.version(1).stores({
      // Primary key is `id`, indexed on `user_id` and `updated_at`
      workouts: 'id, user_id, updated_at, is_favorite',
      // Primary key is `id`, indexed on `user_id` and `started_at`
      sessions: 'id, user_id, started_at, status',
      // Primary key is `user_id` (1:1 relationship with user)
      preferences: 'user_id',
      // Auto-increment primary key, indexed on `table` and `created_at`
      syncQueue: '++id, table, created_at'
    })
  }
}

// Single database instance
export const offlineDb = new OfflineDatabase()

// ============================================================================
// Workouts CRUD
// ============================================================================

/**
 * Save a workout to local storage
 */
export async function saveLocalWorkout(workout: LocalWorkout): Promise<void> {
  await offlineDb.workouts.put(workout)
}

/**
 * Get a workout from local storage by ID
 */
export async function getLocalWorkout(id: string): Promise<LocalWorkout | undefined> {
  return offlineDb.workouts.get(id)
}

/**
 * Get all workouts for a user from local storage, sorted by updated_at desc
 */
export async function getLocalWorkouts(userId: string): Promise<LocalWorkout[]> {
  return offlineDb.workouts
    .where('user_id')
    .equals(userId)
    .reverse()
    .sortBy('updated_at')
}

/**
 * Update a workout in local storage
 */
export async function updateLocalWorkout(
  id: string,
  updates: Partial<LocalWorkout>
): Promise<void> {
  await offlineDb.workouts.update(id, {
    ...updates,
    updated_at: new Date().toISOString()
  })
}

/**
 * Delete a workout from local storage
 */
export async function deleteLocalWorkout(id: string): Promise<void> {
  await offlineDb.workouts.delete(id)
}

/**
 * Bulk save workouts (for syncing from server)
 */
export async function bulkSaveLocalWorkouts(workouts: LocalWorkout[]): Promise<void> {
  await offlineDb.workouts.bulkPut(workouts)
}

/**
 * Clear all workouts for a user (for logout)
 */
export async function clearLocalWorkouts(userId: string): Promise<void> {
  await offlineDb.workouts
    .where('user_id')
    .equals(userId)
    .delete()
}

// ============================================================================
// Sessions CRUD
// ============================================================================

/**
 * Save a session to local storage
 */
export async function saveLocalSession(session: LocalSession): Promise<void> {
  await offlineDb.sessions.put(session)
}

/**
 * Get a session from local storage by ID
 */
export async function getLocalSession(id: string): Promise<LocalSession | undefined> {
  return offlineDb.sessions.get(id)
}

/**
 * Get session history for a user from local storage, sorted by started_at desc
 */
export async function getLocalSessions(
  userId: string,
  limit = 50
): Promise<LocalSession[]> {
  return offlineDb.sessions
    .where('user_id')
    .equals(userId)
    .reverse()
    .sortBy('started_at')
    .then(sessions => sessions.slice(0, limit))
}

/**
 * Update a session in local storage
 */
export async function updateLocalSession(
  id: string,
  updates: Partial<LocalSession>
): Promise<void> {
  await offlineDb.sessions.update(id, updates)
}

/**
 * Delete a session from local storage
 */
export async function deleteLocalSession(id: string): Promise<void> {
  await offlineDb.sessions.delete(id)
}

/**
 * Bulk save sessions (for syncing from server)
 */
export async function bulkSaveLocalSessions(sessions: LocalSession[]): Promise<void> {
  await offlineDb.sessions.bulkPut(sessions)
}

/**
 * Clear all sessions for a user (for logout)
 */
export async function clearLocalSessions(userId: string): Promise<void> {
  await offlineDb.sessions
    .where('user_id')
    .equals(userId)
    .delete()
}

// ============================================================================
// Preferences CRUD
// ============================================================================

/**
 * Save preferences to local storage
 */
export async function saveLocalPreferences(preferences: LocalPreferences): Promise<void> {
  await offlineDb.preferences.put(preferences)
}

/**
 * Get preferences from local storage by user ID
 */
export async function getLocalPreferences(
  userId: string
): Promise<LocalPreferences | undefined> {
  return offlineDb.preferences.get(userId)
}

/**
 * Update preferences in local storage
 */
export async function updateLocalPreferences(
  userId: string,
  updates: Partial<LocalPreferences>
): Promise<void> {
  await offlineDb.preferences.update(userId, {
    ...updates,
    updated_at: new Date().toISOString()
  })
}

/**
 * Delete preferences from local storage (for logout)
 */
export async function deleteLocalPreferences(userId: string): Promise<void> {
  await offlineDb.preferences.delete(userId)
}

// ============================================================================
// Sync Queue CRUD
// ============================================================================

/**
 * Add an entry to the sync queue
 */
export async function addToSyncQueue(
  table: SyncTable,
  operation: SyncOperation,
  recordId: string,
  data: Record<string, unknown> | null = null
): Promise<void> {
  const entry: SyncQueueEntry = {
    table,
    operation,
    record_id: recordId,
    data,
    created_at: new Date().toISOString()
  }
  await offlineDb.syncQueue.add(entry)
}

/**
 * Get all pending sync queue entries in order
 */
export async function getSyncQueue(): Promise<SyncQueueEntry[]> {
  return offlineDb.syncQueue.orderBy('created_at').toArray()
}

/**
 * Remove a sync queue entry after successful sync
 */
export async function removeSyncQueueEntry(id: number): Promise<void> {
  await offlineDb.syncQueue.delete(id)
}

/**
 * Clear all sync queue entries (after full sync or on logout)
 */
export async function clearSyncQueue(): Promise<void> {
  await offlineDb.syncQueue.clear()
}

/**
 * Get count of pending sync entries
 */
export async function getSyncQueueCount(): Promise<number> {
  return offlineDb.syncQueue.count()
}

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * Clear all local data for a user (for logout)
 */
export async function clearAllLocalData(userId: string): Promise<void> {
  await Promise.all([
    clearLocalWorkouts(userId),
    clearLocalSessions(userId),
    deleteLocalPreferences(userId),
    clearSyncQueue()
  ])
}

/**
 * Check if the database is ready
 */
export async function isDatabaseReady(): Promise<boolean> {
  try {
    await offlineDb.open()
    return true
  } catch {
    return false
  }
}
