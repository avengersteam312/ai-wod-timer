/**
 * Sync Service
 *
 * Handles synchronization between local IndexedDB storage and Supabase.
 * Detects online/offline status and processes the sync queue when online.
 * Uses server-wins conflict resolution strategy.
 */
import { supabase } from '@/config/supabase'
import {
  getSyncQueue,
  removeSyncQueueEntry,
  clearSyncQueue,
  getSyncQueueCount,
  bulkSaveLocalWorkouts,
  bulkSaveLocalSessions,
  saveLocalPreferences,
  type SyncQueueEntry,
  type LocalWorkout,
  type LocalSession,
  type LocalPreferences
} from './offlineDb'

/**
 * Sync status for UI feedback
 */
export type SyncStatus = 'idle' | 'syncing' | 'error' | 'offline'

/**
 * Sync event callback type
 */
export type SyncEventCallback = (status: SyncStatus, message?: string) => void

/**
 * Internal state for sync service
 */
let isOnlineStatus = typeof navigator !== 'undefined' ? navigator.onLine : true
let isSyncing = false
let syncEventCallback: SyncEventCallback | null = null
let onlineListener: (() => void) | null = null
let offlineListener: (() => void) | null = null

/**
 * Check if the browser is currently online
 */
export function isOnline(): boolean {
  return isOnlineStatus
}

/**
 * Set callback for sync status events
 */
export function onSyncStatusChange(callback: SyncEventCallback | null): void {
  syncEventCallback = callback
}

/**
 * Emit sync status event
 */
function emitSyncStatus(status: SyncStatus, message?: string): void {
  if (syncEventCallback) {
    syncEventCallback(status, message)
  }
}

/**
 * Initialize sync service with online/offline event listeners
 * Call this once when the app starts (after auth is initialized)
 */
export function initSyncService(): void {
  if (typeof window === 'undefined') return

  // Set initial online status
  isOnlineStatus = navigator.onLine

  // Handle coming online
  onlineListener = () => {
    isOnlineStatus = true
    emitSyncStatus('idle')
    // Automatically sync when coming online
    processSyncQueue().catch(error => {
      console.error('Auto-sync on reconnect failed:', error)
    })
  }

  // Handle going offline
  offlineListener = () => {
    isOnlineStatus = false
    emitSyncStatus('offline')
  }

  window.addEventListener('online', onlineListener)
  window.addEventListener('offline', offlineListener)

  // Initial status
  emitSyncStatus(isOnlineStatus ? 'idle' : 'offline')
}

/**
 * Cleanup sync service event listeners
 * Call this when the app unmounts or user logs out
 */
export function cleanupSyncService(): void {
  if (typeof window === 'undefined') return

  if (onlineListener) {
    window.removeEventListener('online', onlineListener)
    onlineListener = null
  }

  if (offlineListener) {
    window.removeEventListener('offline', offlineListener)
    offlineListener = null
  }

  syncEventCallback = null
}

/**
 * Process all pending items in the sync queue
 * Each item is applied to Supabase and removed from queue on success
 */
export async function processSyncQueue(): Promise<{ success: boolean; synced: number; errors: number }> {
  if (!isOnlineStatus) {
    return { success: false, synced: 0, errors: 0 }
  }

  if (isSyncing) {
    return { success: false, synced: 0, errors: 0 }
  }

  isSyncing = true
  emitSyncStatus('syncing')

  let synced = 0
  let errors = 0

  try {
    const queue = await getSyncQueue()

    if (queue.length === 0) {
      emitSyncStatus('idle')
      return { success: true, synced: 0, errors: 0 }
    }

    for (const entry of queue) {
      try {
        await processQueueEntry(entry)
        if (entry.id !== undefined) {
          await removeSyncQueueEntry(entry.id)
        }
        synced++
      } catch (error) {
        console.error(`Failed to sync entry ${entry.id}:`, error)
        errors++
        // Continue with next entry instead of failing entirely
      }
    }

    emitSyncStatus(errors > 0 ? 'error' : 'idle', errors > 0 ? `${errors} items failed to sync` : undefined)
    return { success: errors === 0, synced, errors }
  } catch (error) {
    console.error('Sync queue processing failed:', error)
    emitSyncStatus('error', 'Sync failed')
    return { success: false, synced, errors }
  } finally {
    isSyncing = false
  }
}

/**
 * Process a single sync queue entry
 * Applies the mutation to Supabase
 */
async function processQueueEntry(entry: SyncQueueEntry): Promise<void> {
  const { table, operation, record_id, data } = entry

  switch (table) {
    case 'workouts':
      await processWorkoutEntry(operation, record_id, data)
      break
    case 'workout_sessions':
      await processSessionEntry(operation, record_id, data)
      break
    case 'user_preferences':
      await processPreferencesEntry(operation, record_id, data)
      break
    default:
      console.warn(`Unknown sync table: ${table}`)
  }
}

/**
 * Process a workout sync entry
 */
async function processWorkoutEntry(
  operation: string,
  recordId: string,
  data: Record<string, unknown> | null
): Promise<void> {
  switch (operation) {
    case 'insert': {
      if (!data) throw new Error('Insert requires data')
      // Check if already exists (server-wins: skip if exists)
      const { data: existing } = await supabase
        .from('workouts')
        .select('id')
        .eq('id', recordId)
        .maybeSingle()

      if (!existing) {
        const { error } = await supabase
          .from('workouts')
          .insert({ id: recordId, ...data })
        if (error) throw error
      }
      break
    }
    case 'update': {
      if (!data) throw new Error('Update requires data')
      // Server-wins: just apply the update, server version takes precedence on conflict
      const { error } = await supabase
        .from('workouts')
        .update(data)
        .eq('id', recordId)
      if (error) throw error
      break
    }
    case 'delete': {
      const { error } = await supabase
        .from('workouts')
        .delete()
        .eq('id', recordId)
      if (error) throw error
      break
    }
  }
}

/**
 * Process a session sync entry
 */
async function processSessionEntry(
  operation: string,
  recordId: string,
  data: Record<string, unknown> | null
): Promise<void> {
  switch (operation) {
    case 'insert': {
      if (!data) throw new Error('Insert requires data')
      // Check if already exists (server-wins: skip if exists)
      const { data: existing } = await supabase
        .from('workout_sessions')
        .select('id')
        .eq('id', recordId)
        .maybeSingle()

      if (!existing) {
        const { error } = await supabase
          .from('workout_sessions')
          .insert({ id: recordId, ...data })
        if (error) throw error
      }
      break
    }
    case 'update': {
      if (!data) throw new Error('Update requires data')
      // Server-wins: apply the update
      const { error } = await supabase
        .from('workout_sessions')
        .update(data)
        .eq('id', recordId)
      if (error) throw error
      break
    }
    case 'delete': {
      const { error } = await supabase
        .from('workout_sessions')
        .delete()
        .eq('id', recordId)
      if (error) throw error
      break
    }
  }
}

/**
 * Process a preferences sync entry
 */
async function processPreferencesEntry(
  operation: string,
  recordId: string,
  data: Record<string, unknown> | null
): Promise<void> {
  switch (operation) {
    case 'insert':
    case 'update': {
      if (!data) throw new Error('Insert/Update requires data')
      // Use upsert for preferences (always one record per user)
      const { error } = await supabase
        .from('user_preferences')
        .upsert({ user_id: recordId, ...data }, { onConflict: 'user_id' })
      if (error) throw error
      break
    }
    case 'delete': {
      const { error } = await supabase
        .from('user_preferences')
        .delete()
        .eq('user_id', recordId)
      if (error) throw error
      break
    }
  }
}

/**
 * Pull fresh data from server and update local storage
 * Server-wins: Server data overwrites local data
 */
export async function pullFromServer(userId: string): Promise<void> {
  if (!isOnlineStatus) {
    throw new Error('Cannot pull from server while offline')
  }

  try {
    // Fetch all user data from server in parallel
    const [workoutsResult, sessionsResult, preferencesResult] = await Promise.all([
      supabase.from('workouts').select('*').order('updated_at', { ascending: false }),
      supabase.from('workout_sessions').select('*').order('started_at', { ascending: false }).limit(100),
      supabase.from('user_preferences').select('*').eq('user_id', userId).maybeSingle()
    ])

    // Update local storage with server data (server-wins)
    if (workoutsResult.data) {
      await bulkSaveLocalWorkouts(workoutsResult.data as LocalWorkout[])
    }

    if (sessionsResult.data) {
      await bulkSaveLocalSessions(sessionsResult.data as LocalSession[])
    }

    if (preferencesResult.data) {
      await saveLocalPreferences(preferencesResult.data as LocalPreferences)
    }
  } catch (error) {
    console.error('Failed to pull from server:', error)
    throw error
  }
}

/**
 * Full sync: push pending changes then pull from server
 */
export async function fullSync(userId: string): Promise<{ success: boolean; synced: number; errors: number }> {
  if (!isOnlineStatus) {
    return { success: false, synced: 0, errors: 0 }
  }

  // First, push pending changes
  const pushResult = await processSyncQueue()

  // Then, pull fresh data from server (server-wins)
  try {
    await pullFromServer(userId)
  } catch (error) {
    console.error('Pull from server failed during full sync:', error)
    return { ...pushResult, success: false }
  }

  return pushResult
}

/**
 * Get count of pending sync queue items
 */
export async function getPendingSyncCount(): Promise<number> {
  return getSyncQueueCount()
}

/**
 * Check if there are pending sync items
 */
export async function hasPendingSync(): Promise<boolean> {
  const count = await getSyncQueueCount()
  return count > 0
}

/**
 * Clear the entire sync queue (use with caution - discards offline changes)
 */
export async function discardPendingSync(): Promise<void> {
  await clearSyncQueue()
}
