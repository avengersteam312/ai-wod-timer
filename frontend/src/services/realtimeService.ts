/**
 * Realtime Service
 *
 * Handles Supabase Realtime subscriptions for syncing changes
 * across devices. When remote changes are detected, updates local IndexedDB.
 */
import { supabase } from '@/config/supabase'
import type { RealtimeChannel, RealtimePostgresChangesPayload } from '@supabase/supabase-js'
import {
  saveLocalWorkout,
  deleteLocalWorkout,
  saveLocalPreferences,
  type LocalWorkout,
  type LocalPreferences
} from './offlineDb'

/**
 * Realtime event callback types
 */
export type RealtimeEventCallback = (
  table: 'workouts' | 'user_preferences',
  event: 'INSERT' | 'UPDATE' | 'DELETE',
  record: LocalWorkout | LocalPreferences | null
) => void

/**
 * Internal state for realtime service
 */
let workoutsChannel: RealtimeChannel | null = null
let preferencesChannel: RealtimeChannel | null = null
let eventCallback: RealtimeEventCallback | null = null

/**
 * Set callback for realtime events (for UI updates)
 */
export function onRealtimeEvent(callback: RealtimeEventCallback | null): void {
  eventCallback = callback
}

/**
 * Emit realtime event to callback
 */
function emitEvent(
  table: 'workouts' | 'user_preferences',
  event: 'INSERT' | 'UPDATE' | 'DELETE',
  record: LocalWorkout | LocalPreferences | null
): void {
  if (eventCallback) {
    eventCallback(table, event, record)
  }
}

/**
 * Subscribe to workouts table changes for the current user
 */
export function subscribeToWorkouts(userId: string): void {
  if (workoutsChannel) {
    console.warn('Already subscribed to workouts channel')
    return
  }

  workoutsChannel = supabase
    .channel('workouts-changes')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'workouts',
        filter: `user_id=eq.${userId}`
      },
      async (payload: RealtimePostgresChangesPayload<LocalWorkout>) => {
        await handleWorkoutChange(payload)
      }
    )
    .subscribe((status, err) => {
      if (status === 'SUBSCRIBED') {
        console.log('Subscribed to workouts realtime channel')
      } else if (status === 'CHANNEL_ERROR') {
        console.error('Workouts channel error:', err)
      }
    })
}

/**
 * Handle incoming workout changes from Realtime
 */
async function handleWorkoutChange(
  payload: RealtimePostgresChangesPayload<LocalWorkout>
): Promise<void> {
  const { eventType, new: newRecord, old: oldRecord } = payload

  try {
    switch (eventType) {
      case 'INSERT': {
        const workout = newRecord as LocalWorkout
        await saveLocalWorkout(workout)
        emitEvent('workouts', 'INSERT', workout)
        break
      }
      case 'UPDATE': {
        const workout = newRecord as LocalWorkout
        await saveLocalWorkout(workout)
        emitEvent('workouts', 'UPDATE', workout)
        break
      }
      case 'DELETE': {
        const workout = oldRecord as LocalWorkout
        if (workout?.id) {
          await deleteLocalWorkout(workout.id)
          emitEvent('workouts', 'DELETE', workout)
        }
        break
      }
    }
  } catch (error) {
    console.error('Error handling workout realtime change:', error)
  }
}

/**
 * Subscribe to user_preferences table changes for the current user
 */
export function subscribeToPreferences(userId: string): void {
  if (preferencesChannel) {
    console.warn('Already subscribed to preferences channel')
    return
  }

  preferencesChannel = supabase
    .channel('preferences-changes')
    .on(
      'postgres_changes',
      {
        event: '*',
        schema: 'public',
        table: 'user_preferences',
        filter: `user_id=eq.${userId}`
      },
      async (payload: RealtimePostgresChangesPayload<LocalPreferences>) => {
        await handlePreferencesChange(payload)
      }
    )
    .subscribe((status, err) => {
      if (status === 'SUBSCRIBED') {
        console.log('Subscribed to preferences realtime channel')
      } else if (status === 'CHANNEL_ERROR') {
        console.error('Preferences channel error:', err)
      }
    })
}

/**
 * Handle incoming preferences changes from Realtime
 */
async function handlePreferencesChange(
  payload: RealtimePostgresChangesPayload<LocalPreferences>
): Promise<void> {
  const { eventType, new: newRecord } = payload

  try {
    switch (eventType) {
      case 'INSERT':
      case 'UPDATE': {
        const preferences = newRecord as LocalPreferences
        await saveLocalPreferences(preferences)
        emitEvent('user_preferences', eventType, preferences)
        break
      }
      case 'DELETE': {
        // Preferences deletion is rare, just emit event
        emitEvent('user_preferences', 'DELETE', null)
        break
      }
    }
  } catch (error) {
    console.error('Error handling preferences realtime change:', error)
  }
}

/**
 * Subscribe to all relevant tables for the current user
 */
export function subscribeToAll(userId: string): void {
  subscribeToWorkouts(userId)
  subscribeToPreferences(userId)
}

/**
 * Unsubscribe from workouts channel
 */
export async function unsubscribeFromWorkouts(): Promise<void> {
  if (workoutsChannel) {
    await supabase.removeChannel(workoutsChannel)
    workoutsChannel = null
    console.log('Unsubscribed from workouts realtime channel')
  }
}

/**
 * Unsubscribe from preferences channel
 */
export async function unsubscribeFromPreferences(): Promise<void> {
  if (preferencesChannel) {
    await supabase.removeChannel(preferencesChannel)
    preferencesChannel = null
    console.log('Unsubscribed from preferences realtime channel')
  }
}

/**
 * Unsubscribe from all channels (call on logout or app unmount)
 */
export async function unsubscribeFromAll(): Promise<void> {
  await Promise.all([
    unsubscribeFromWorkouts(),
    unsubscribeFromPreferences()
  ])
  eventCallback = null
}

/**
 * Check if currently subscribed to workouts
 */
export function isSubscribedToWorkouts(): boolean {
  return workoutsChannel !== null
}

/**
 * Check if currently subscribed to preferences
 */
export function isSubscribedToPreferences(): boolean {
  return preferencesChannel !== null
}
