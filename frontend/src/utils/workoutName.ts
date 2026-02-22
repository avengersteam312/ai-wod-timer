import type { ParsedWorkout } from '@/types/workout'

export const MAX_WORKOUT_NAME_LENGTH = 18

/**
 * Propose a short workout name from the workout description (notes, raw_text, or movements).
 * Result is capped at MAX_WORKOUT_NAME_LENGTH for display consistency.
 */
export function proposeWorkoutName(workout: ParsedWorkout | null): string {
  if (!workout) return ''

  const max = MAX_WORKOUT_NAME_LENGTH

  // Prefer user description / notes (e.g. "AMRAP 15 min: 10 burpees, 15 air squats")
  const fromText = (text: string) => {
    const line = text.trim().split(/\n/)[0]?.trim() ?? ''
    const collapsed = line.replace(/\s+/g, ' ').trim()
    if (collapsed.length <= max) return collapsed
    return collapsed.slice(0, max - 3) + '...'
  }

  if (workout.notes?.trim()) {
    const name = fromText(workout.notes)
    if (name) return name
  }
  if (workout.raw_text?.trim()) {
    const name = fromText(workout.raw_text)
    if (name) return name
  }

  // Fallback: type + first movement names
  const type = workout.workout_type.toUpperCase()
  const movementNames = workout.movements
    ?.filter((m) => m.name?.trim())
    .map((m) => m.name!.trim())
    .slice(0, 2) ?? []
  const combined = movementNames.length
    ? `${type} ${movementNames.join(', ')}`
    : type
  const collapsed = combined.replace(/\s+/g, ' ').trim()
  if (collapsed.length <= max) return collapsed
  const fromMovements = collapsed.slice(0, max - 3) + '...'
  if (fromMovements.length > 0) return fromMovements

  // Last resort: type + date
  return fallbackWorkoutName(workout)
}

/** Fallback name when no description is available (type + date). */
export function fallbackWorkoutName(workout: ParsedWorkout | null): string {
  if (!workout) return ''
  const type = workout.workout_type.toUpperCase()
  const date = new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
  const name = `${type} - ${date}`
  return name.length <= MAX_WORKOUT_NAME_LENGTH ? name : name.slice(0, MAX_WORKOUT_NAME_LENGTH - 3) + '...'
}
