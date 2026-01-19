export type WorkoutType = 'amrap' | 'emom' | 'for_time' | 'tabata' | 'intervals' | 'stopwatch' | 'custom'

export interface Movement {
  name: string
  reps?: number
  duration?: number
  weight?: string
  notes?: string
}

export interface AudioCue {
  time: number
  message: string
  type: string
}

export interface Interval {
  duration: number
  label: string
  type: string
}

export interface TimerConfig {
  type: string
  total_seconds?: number
  rounds?: number
  intervals: Interval[]
  audio_cues: AudioCue[]
}

export interface ParsedWorkout {
  workout_type: WorkoutType
  movements: Movement[]
  rounds?: number
  duration?: number
  time_cap?: number
  timer_config: TimerConfig
  raw_text: string
  ai_interpretation?: string
}

export interface WorkoutParseRequest {
  workout_text: string
}
