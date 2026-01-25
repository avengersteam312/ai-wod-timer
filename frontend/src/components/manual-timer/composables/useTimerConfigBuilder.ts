import type { TimerConfig, Interval, ParsedWorkout } from '@/types/workout'

export type TimerType = 'rest' | 'stopwatch' | 'amrap' | 'for_time' | 'tabata' | 'custom_interval' | 'emom' | 'work_rest'

export interface RestConfig {
  minutes: number
  seconds: number
}

export interface DurationConfig {
  minutes: number
  seconds: number
}

export interface TabataConfig {
  workSeconds: number
  restSeconds: number
  rounds: number
}

export interface CustomIntervalConfig {
  workMinutes: number
  workSeconds: number
  restMinutes: number
  restSeconds: number
  rounds: number
}

export interface EmomConfig {
  rounds: number
  intervalMinutes: number
}

export interface WorkRestConfig {
  rounds: number
}

export function buildTimerConfig(
  type: TimerType,
  config: {
    rest?: RestConfig
    duration?: DurationConfig
    tabata?: TabataConfig
    customInterval?: CustomIntervalConfig
    emom?: EmomConfig
    workRest?: WorkRestConfig
  }
): TimerConfig {
  switch (type) {
    case 'rest': {
      const { minutes = 1, seconds = 0 } = config.rest || {}
      const duration = minutes * 60 + seconds
      return {
        type: 'countdown',
        total_seconds: duration,
        intervals: [{ duration, label: 'Rest', type: 'rest' }],
        audio_cues: [
          { time: -10, message: 'ten seconds', type: 'countdown' },
          { time: -3, message: '3', type: 'countdown' },
          { time: -2, message: '2', type: 'countdown' },
          { time: -1, message: '1', type: 'countdown' }
        ]
      }
    }

    case 'stopwatch':
      return {
        type: 'stopwatch',
        total_seconds: undefined,
        intervals: [],
        audio_cues: []
      }

    case 'amrap': {
      const { minutes = 10, seconds = 0 } = config.duration || {}
      const duration = minutes * 60 + seconds
      return {
        type: 'amrap',
        total_seconds: duration,
        intervals: [{ duration, label: 'AMRAP', type: 'work' }],
        audio_cues: [
          { time: -60, message: 'one minute remaining', type: 'countdown' },
          { time: -30, message: 'thirty seconds', type: 'countdown' },
          { time: -10, message: 'ten seconds', type: 'countdown' },
          { time: -3, message: '3', type: 'countdown' },
          { time: -2, message: '2', type: 'countdown' },
          { time: -1, message: '1', type: 'countdown' }
        ]
      }
    }

    case 'for_time': {
      const { minutes = 0, seconds = 0 } = config.duration || {}
      const duration = minutes * 60 + seconds
      if (duration === 0) {
        return {
          type: 'for_time',
          total_seconds: undefined,
          intervals: [],
          audio_cues: []
        }
      }
      return {
        type: 'for_time',
        total_seconds: duration,
        intervals: [{ duration, label: 'For Time', type: 'work' }],
        audio_cues: [
          { time: -60, message: 'one minute remaining', type: 'countdown' },
          { time: -30, message: 'thirty seconds', type: 'countdown' },
          { time: -10, message: 'ten seconds', type: 'countdown' },
          { time: -3, message: '3', type: 'countdown' },
          { time: -2, message: '2', type: 'countdown' },
          { time: -1, message: '1', type: 'countdown' }
        ]
      }
    }

    case 'tabata': {
      const { workSeconds = 20, restSeconds = 10, rounds = 8 } = config.tabata || {}
      const intervals: Interval[] = []
      for (let i = 0; i < rounds; i++) {
        intervals.push({ duration: workSeconds, label: 'Work', type: 'work' })
        if (i < rounds - 1) {
          intervals.push({ duration: restSeconds, label: 'Rest', type: 'rest' })
        }
      }
      const totalSeconds = intervals.reduce((sum, i) => sum + i.duration, 0)
      return {
        type: 'tabata',
        total_seconds: totalSeconds,
        rounds,
        intervals,
        audio_cues: [
          { time: -3, message: '3', type: 'countdown' },
          { time: -2, message: '2', type: 'countdown' },
          { time: -1, message: '1', type: 'countdown' }
        ]
      }
    }

    case 'custom_interval': {
      const {
        workMinutes = 0,
        workSeconds = 30,
        restMinutes = 0,
        restSeconds = 10,
        rounds = 8
      } = config.customInterval || {}
      const workDuration = workMinutes * 60 + workSeconds
      const restDuration = restMinutes * 60 + restSeconds
      const intervals: Interval[] = []
      for (let i = 0; i < rounds; i++) {
        intervals.push({ duration: workDuration, label: 'Work', type: 'work' })
        if (restDuration > 0 && i < rounds - 1) {
          intervals.push({ duration: restDuration, label: 'Rest', type: 'rest' })
        }
      }
      const totalSeconds = intervals.reduce((sum, i) => sum + i.duration, 0)
      return {
        type: 'intervals',
        total_seconds: totalSeconds,
        rounds,
        intervals,
        audio_cues: [
          { time: -3, message: '3', type: 'countdown' },
          { time: -2, message: '2', type: 'countdown' },
          { time: -1, message: '1', type: 'countdown' }
        ]
      }
    }

    case 'emom': {
      const { rounds = 10, intervalMinutes = 1 } = config.emom || {}
      const intervalSeconds = intervalMinutes * 60
      const intervals: Interval[] = []
      for (let i = 0; i < rounds; i++) {
        intervals.push({ duration: intervalSeconds, label: `Round ${i + 1}`, type: 'work' })
      }
      const totalSeconds = rounds * intervalSeconds
      return {
        type: 'emom',
        total_seconds: totalSeconds,
        rounds,
        intervals,
        audio_cues: [
          { time: -3, message: '3', type: 'countdown' },
          { time: -2, message: '2', type: 'countdown' },
          { time: -1, message: '1', type: 'countdown' }
        ]
      }
    }

    case 'work_rest': {
      const { rounds = 5 } = config.workRest || {}
      return {
        type: 'work_rest',
        total_seconds: undefined,
        rounds,
        intervals: [],
        audio_cues: []
      }
    }

    default:
      return {
        type: 'stopwatch',
        total_seconds: undefined,
        intervals: [],
        audio_cues: []
      }
  }
}

const typeLabels: Record<TimerType, string> = {
  rest: 'Rest Timer',
  stopwatch: 'Stopwatch',
  amrap: 'AMRAP',
  for_time: 'For Time',
  tabata: 'Tabata',
  custom_interval: 'Intervals',
  emom: 'EMOM',
  work_rest: 'Work & Rest'
}

const workoutTypeMap: Record<TimerType, ParsedWorkout['workout_type']> = {
  rest: 'rest',
  stopwatch: 'stopwatch',
  amrap: 'amrap',
  for_time: 'for_time',
  tabata: 'tabata',
  custom_interval: 'intervals',
  emom: 'emom',
  work_rest: 'work_rest'
}

export function buildManualWorkout(type: TimerType, timerConfig: TimerConfig): ParsedWorkout {
  return {
    workout_type: workoutTypeMap[type],
    movements: [{ name: typeLabels[type] }],
    rounds: timerConfig.rounds,
    duration: timerConfig.total_seconds,
    timer_config: timerConfig,
    raw_text: `Manual ${typeLabels[type]} timer`
  }
}

export function getTypeLabel(type: TimerType): string {
  return typeLabels[type]
}
