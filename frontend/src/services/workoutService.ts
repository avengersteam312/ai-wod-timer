/**
 * Workout Service
 *
 * Handles CRUD operations for workouts using Supabase.
 * Workouts store parsed workout configurations that can be reused.
 */
import { supabase } from '@/config/supabase'
import type { ParsedWorkout } from '@/types/workout'

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
 * Save a parsed workout to Supabase
 *
 * @param workout - The parsed workout configuration to save
 * @param name - Display name for the workout
 * @returns The saved workout record
 * @throws Error if user is not authenticated or save fails
 */
export async function saveWorkout(workout: ParsedWorkout, name: string): Promise<Workout> {
  // Get current user
  const { data: { user }, error: userError } = await supabase.auth.getUser()

  if (userError || !user) {
    throw new Error('You must be logged in to save workouts')
  }

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

  return data as Workout
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
