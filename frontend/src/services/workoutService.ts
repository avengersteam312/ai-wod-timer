/**
 * Workout Service
 *
 * Handles CRUD operations for workouts using Supabase.
 * Workouts store parsed workout configurations that can be reused.
 * Supports offline-first pattern: saves locally when offline and syncs when online.
 */
import { supabase } from '@/config/supabase'
import type { ParsedWorkout } from '@/types/workout'
import { isOnline } from '@/services/syncService'
import {
  createWorkoutOffline,
  updateWorkoutOffline,
  deleteWorkoutOffline
} from '@/services/offlineMutationService'
import {
  getLocalWorkouts,
  getLocalWorkout
} from '@/services/offlineDb'

/**
 * Workout record as stored in Supabase
 */
export interface Workout {
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
 * Data required to insert a new workout
 */
interface WorkoutInsert {
  user_id: string
  name: string
  raw_input: string | null
  parsed_config: ParsedWorkout
  is_favorite?: boolean
}

/**
 * Data that can be updated on an existing workout
 */
interface WorkoutUpdate {
  name?: string
  is_favorite?: boolean
}

/**
 * Result of a save operation, includes whether it was saved offline
 */
export interface SaveResult {
  workout: Workout
  savedOffline: boolean
}

/**
 * Save a parsed workout to Supabase (or locally if offline)
 *
 * @param workout - The parsed workout configuration to save
 * @param name - Display name for the workout
 * @returns The saved workout record and whether it was saved offline
 * @throws Error if user is not authenticated or save fails
 */
export async function saveWorkout(workout: ParsedWorkout, name: string): Promise<SaveResult> {
  // Get current user
  const { data: { user }, error: userError } = await supabase.auth.getUser()

  if (userError || !user) {
    throw new Error('You must be logged in to save workouts')
  }

  // If offline, save locally and queue for sync
  if (!isOnline()) {
    const localWorkout = await createWorkoutOffline({
      userId: user.id,
      name,
      workout
    })
    return {
      workout: localWorkout as Workout,
      savedOffline: true
    }
  }

  // Online: save directly to Supabase
  const workoutData: WorkoutInsert = {
    user_id: user.id,
    name,
    raw_input: workout.raw_text ?? null,
    parsed_config: workout,
    is_favorite: false
  }

  const { data, error } = await supabase
    .from('workouts')
    .insert(workoutData)
    .select()
    .single()

  if (error) {
    console.error('Error saving workout:', error)
    throw new Error('Failed to save workout. Please try again.')
  }

  return {
    workout: data as Workout,
    savedOffline: false
  }
}

/**
 * Get a single workout by ID
 *
 * @param id - The workout UUID
 * @returns The workout record
 * @throws Error if not found, not owned by user, or fetch fails
 */
export async function getWorkout(id: string): Promise<Workout> {
  const { data, error } = await supabase
    .from('workouts')
    .select('*')
    .eq('id', id)
    .single()

  if (error) {
    if (error.code === 'PGRST116') {
      // Row not found (RLS filters out workouts not owned by user)
      throw new Error('Workout not found')
    }
    console.error('Error fetching workout:', error)
    throw new Error('Failed to load workout. Please try again.')
  }

  return data as Workout
}

/**
 * Get all workouts for the current user
 * Falls back to local storage when offline
 *
 * @returns Array of workouts sorted by updated_at descending (most recent first)
 * @throws Error if user is not authenticated or fetch fails
 */
export async function getWorkouts(): Promise<Workout[]> {
  // Get current user
  const { data: { user }, error: userError } = await supabase.auth.getUser()

  if (userError || !user) {
    throw new Error('You must be logged in to view workouts')
  }

  // If offline, return from local storage
  if (!isOnline()) {
    const localWorkouts = await getLocalWorkouts(user.id)
    return localWorkouts as Workout[]
  }

  // Online: fetch from Supabase
  const { data, error } = await supabase
    .from('workouts')
    .select('*')
    .order('updated_at', { ascending: false })

  if (error) {
    console.error('Error fetching workouts:', error)
    // Fall back to local storage on error
    try {
      const localWorkouts = await getLocalWorkouts(user.id)
      return localWorkouts as Workout[]
    } catch {
      throw new Error('Failed to load workouts. Please try again.')
    }
  }

  return (data ?? []) as Workout[]
}

/**
 * Update an existing workout
 * Saves locally and queues for sync when offline
 *
 * @param id - The workout UUID to update
 * @param updates - Fields to update (name and/or is_favorite)
 * @returns The updated workout record and whether it was updated offline
 * @throws Error if not found, not owned by user, or update fails
 */
export async function updateWorkout(id: string, updates: WorkoutUpdate): Promise<{ workout: Workout; updatedOffline: boolean }> {
  // If offline, update locally and queue for sync
  if (!isOnline()) {
    await updateWorkoutOffline(id, updates)
    const localWorkout = await getLocalWorkout(id)
    if (!localWorkout) {
      throw new Error('Workout not found')
    }
    return {
      workout: localWorkout as Workout,
      updatedOffline: true
    }
  }

  // Online: update in Supabase
  const { data, error } = await supabase
    .from('workouts')
    .update(updates)
    .eq('id', id)
    .select()
    .single()

  if (error) {
    if (error.code === 'PGRST116') {
      throw new Error('Workout not found')
    }
    console.error('Error updating workout:', error)
    throw new Error('Failed to update workout. Please try again.')
  }

  return {
    workout: data as Workout,
    updatedOffline: false
  }
}

/**
 * Delete a workout by ID
 * Deletes locally and queues for sync when offline
 *
 * @param id - The workout UUID to delete
 * @returns Whether the delete was performed offline
 * @throws Error if not found, not owned by user, or delete fails
 */
export async function deleteWorkout(id: string): Promise<{ deletedOffline: boolean }> {
  // If offline, delete locally and queue for sync
  if (!isOnline()) {
    await deleteWorkoutOffline(id)
    return { deletedOffline: true }
  }

  // Online: delete from Supabase
  const { error } = await supabase
    .from('workouts')
    .delete()
    .eq('id', id)

  if (error) {
    if (error.code === 'PGRST116') {
      throw new Error('Workout not found')
    }
    console.error('Error deleting workout:', error)
    throw new Error('Failed to delete workout. Please try again.')
  }

  return { deletedOffline: false }
}
