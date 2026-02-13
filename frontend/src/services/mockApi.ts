import type { WorkoutParseRequest, ParsedWorkout, WorkoutType } from '@/types/workout'

/**
 * Mock API for testing without backend
 * Simulates AI workout parsing with predefined patterns
 */

function parseMockWorkout(text: string): ParsedWorkout {
  const textLower = text.toLowerCase()

  // Detect workout type
  let workoutType: WorkoutType = 'custom'
  let duration: number | undefined
  let rounds: number | undefined

  if (textLower.includes('amrap')) {
    workoutType = 'amrap'
    const match = text.match(/amrap\s+(\d+)\s*min/i)
    if (match?.[1]) duration = parseInt(match[1]) * 60
  } else if (textLower.includes('emom')) {
    workoutType = 'emom'
    const match = text.match(/emom\s+(\d+)\s*min/i)
    if (match?.[1]) duration = parseInt(match[1]) * 60
  } else if (textLower.includes('for time')) {
    workoutType = 'for_time'
  } else if (textLower.includes('tabata')) {
    workoutType = 'tabata'
    duration = 4 * 60 // 4 minutes (8 rounds of 20s work + 10s rest)
  }

  // Detect rounds
  const roundsMatch = text.match(/(\d+)\s+rounds/i)
  if (roundsMatch?.[1]) rounds = parseInt(roundsMatch[1])

  // Parse movements (simple pattern matching)
  const movements = []
  const lines = text.split('\n')

  for (const line of lines) {
    const repsMatch = line.match(/(\d+)\s+(.+)/i)
    if (repsMatch?.[1] && repsMatch[2] && !line.toLowerCase().includes('min') && !line.toLowerCase().includes('rounds')) {
      const reps = parseInt(repsMatch[1])
      let name = repsMatch[2].trim()

      // Extract weight if present
      let weight: string | undefined
      const weightMatch = name.match(/\(([^)]+)\)/)
      if (weightMatch) {
        weight = weightMatch[1]
        name = name.replace(/\([^)]+\)/, '').trim()
      }

      movements.push({ name, reps, weight })
    }
  }

  // Generate timer config
  const intervals = generateIntervals(workoutType, duration, rounds)
  const timerConfig = {
    type: workoutType === 'emom' || workoutType === 'tabata' ? 'intervals' : 'countdown',
    total_seconds: duration,
    rounds,
    intervals: intervals,
    audio_cues: generateAudioCues(workoutType, duration, intervals),
  }

  return {
    workout_type: workoutType,
    movements,
    rounds,
    duration,
    timer_config: timerConfig,
    raw_text: text,
    ai_interpretation: `Mock parsing detected: ${workoutType.toUpperCase()} workout with ${movements.length} movements${duration ? ` for ${Math.floor(duration / 60)} minutes` : ''}${rounds ? `, ${rounds} rounds` : ''}.`,
  }
}

function generateIntervals(workoutType: WorkoutType, duration?: number, _rounds?: number) {
  const intervals = []

  if (workoutType === 'emom' && duration) {
    // EMOM: Each minute is a work interval
    const numIntervals = Math.floor(duration / 60)
    for (let i = 0; i < numIntervals; i++) {
      intervals.push({
        duration: 60,
        label: `Minute ${i + 1}`,
        type: 'work'
      })
    }
  } else if (workoutType === 'tabata') {
    // Tabata: 20s work / 10s rest for 8 rounds
    for (let i = 0; i < 8; i++) {
      intervals.push({
        duration: 20,
        label: `Round ${i + 1} - Work`,
        type: 'work'
      })
      if (i < 7) { // No rest after last round
        intervals.push({
          duration: 10,
          label: `Rest`,
          type: 'rest'
        })
      }
    }
  }

  return intervals
}

function generateAudioCues(workoutType: WorkoutType, duration?: number, _intervals?: unknown[]) {
  const cues = []

  if (duration) {
    // For non-interval workouts, add standard time warnings
    if (workoutType === 'amrap' || workoutType === 'for_time') {
      if (duration >= 600) {
        cues.push({ time: Math.floor(duration / 2), message: 'Halfway point', type: 'announcement' })
      }
      if (duration >= 300) {
        cues.push({ time: duration - 300, message: '5 minutes remaining', type: 'warning' })
      }
      if (duration >= 60) {
        cues.push({ time: duration - 60, message: '1 minute remaining', type: 'warning' })
      }
      if (duration >= 30) {
        cues.push({ time: duration - 30, message: '30 seconds', type: 'warning' })
      }
      if (duration >= 10) {
        cues.push({ time: duration - 10, message: '10 seconds', type: 'warning' })
      }
    }

    cues.push({ time: duration, message: 'Time! Great work!', type: 'completion' })
  }

  return cues
}

export const mockWorkoutApi = {
  parseWorkout: async (request: WorkoutParseRequest): Promise<ParsedWorkout> => {
    // Simulate API delay
    await new Promise(resolve => setTimeout(resolve, 500))

    return parseMockWorkout(request.workout_text)
  },
}
