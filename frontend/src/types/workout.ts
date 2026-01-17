export enum WorkoutType {
  AMRAP = 'amrap',
  EMOM = 'emom',
  FOR_TIME = 'for_time',
  TABATA = 'tabata',
  CHIPPER = 'chipper',
  ROUNDS = 'rounds',
  CUSTOM = 'custom',
}

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
  rest_between_rounds?: number
}

export interface ParsedWorkout {
  workout_type: WorkoutType
  movements: Movement[]
  rounds?: number
  duration?: number
  time_cap?: number
  rest_between_rounds?: number
  timer_config: TimerConfig
  raw_text: string
  ai_interpretation?: string
}

export interface WorkoutParseRequest {
  workout_text: string
}
