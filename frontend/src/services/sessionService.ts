/**
 * Session Service
 *
 * Handles CRUD operations for workout sessions using Supabase.
 * Sessions track in-progress, completed, and abandoned workout attempts.
 */
import { supabase } from '@/config/supabase'
import type { ParsedWorkout } from '@/types/workout'

/**
 * Session status values
 */
export type SessionStatus = 'in_progress' | 'completed' | 'abandoned'

/**
 * Workout session record as stored in Supabase
 */
export interface Session {
  id: string
  user_id: string
  workout_id: string | null
  workout_snapshot: ParsedWorkout
  started_at: string
  completed_at: string | null
  duration_seconds: number | null
  status: SessionStatus
}

/**
 * Data required to insert a new session
 */
interface SessionInsert {
  user_id: string
  workout_id: string | null
  workout_snapshot: ParsedWorkout
  status: SessionStatus
}

/**
 * Start a new workout session
 *
 * @param workout - The parsed workout configuration (will be stored as snapshot)
 * @param workoutId - Optional ID of a saved workout (for tracking purposes)
 * @returns The created session record with status 'in_progress'
 * @throws Error if user is not authenticated or insert fails
 */
export async function startSession(
  workout: ParsedWorkout,
  workoutId?: string
): Promise<Session> {
  // Get current user
  const { data: { user }, error: userError } = await supabase.auth.getUser()

  if (userError || !user) {
    throw new Error('You must be logged in to start a session')
  }

  const sessionData: SessionInsert = {
    user_id: user.id,
    workout_id: workoutId ?? null,
    workout_snapshot: workout,
    status: 'in_progress'
  }

  const { data, error } = await supabase
    .from('workout_sessions')
    .insert(sessionData)
    .select()
    .single()

  if (error) {
    console.error('Error starting session:', error)
    throw new Error('Failed to start session. Please try again.')
  }

  return data as Session
}

/**
 * Complete a workout session
 *
 * @param sessionId - The session UUID to complete
 * @param durationSeconds - Total duration of the workout in seconds
 * @returns The updated session record with status 'completed'
 * @throws Error if not found, not owned by user, or update fails
 */
export async function completeSession(
  sessionId: string,
  durationSeconds: number
): Promise<Session> {
  const { data, error } = await supabase
    .from('workout_sessions')
    .update({
      status: 'completed' as SessionStatus,
      completed_at: new Date().toISOString(),
      duration_seconds: durationSeconds
    })
    .eq('id', sessionId)
    .select()
    .single()

  if (error) {
    if (error.code === 'PGRST116') {
      throw new Error('Session not found')
    }
    console.error('Error completing session:', error)
    throw new Error('Failed to complete session. Please try again.')
  }

  return data as Session
}
