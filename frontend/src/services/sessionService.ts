/**
 * Session Service
 *
 * Handles CRUD operations for workout sessions using Supabase.
 * Sessions track in-progress, completed, and abandoned workout attempts.
 */
import { supabase } from '@/config/supabase'
import type { ParsedWorkout } from '@/types/workout'
import type {
  WorkoutSession,
  WorkoutSessionInsert,
  SessionStatus
} from '@/types/supabase'

// Re-export types for consumers of this service
// Use 'Session' as alias for backward compatibility
export type Session = WorkoutSession
export type { SessionStatus }

/**
 * Data required to insert a new session via this service
 */
type SessionInsertData = Pick<WorkoutSessionInsert, 'user_id' | 'workout_id' | 'workout_snapshot' | 'status'>

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

  const sessionData: SessionInsertData = {
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

/**
 * Abandon a workout session
 *
 * @param sessionId - The session UUID to abandon
 * @throws Error if not found, not owned by user, or update fails
 */
export async function abandonSession(sessionId: string): Promise<void> {
  const { error } = await supabase
    .from('workout_sessions')
    .update({
      status: 'abandoned' as SessionStatus,
      completed_at: new Date().toISOString()
    })
    .eq('id', sessionId)

  if (error) {
    console.error('Error abandoning session:', error)
    throw new Error('Failed to abandon session. Please try again.')
  }
}

/**
 * Get session history for the current user
 *
 * @param limit - Maximum number of sessions to return (default: 50)
 * @returns Array of sessions sorted by started_at desc, including workout_snapshot for display
 * @throws Error if user is not authenticated or query fails
 */
export async function getSessionHistory(limit = 50): Promise<Session[]> {
  const { data, error } = await supabase
    .from('workout_sessions')
    .select('*')
    .order('started_at', { ascending: false })
    .limit(limit)

  if (error) {
    console.error('Error fetching session history:', error)
    throw new Error('Failed to load session history. Please try again.')
  }

  return (data ?? []) as Session[]
}
