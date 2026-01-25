import type { WorkoutType } from '@/types/workout'

export interface TimerLayoutConfig {
  showTimerBlock: boolean
  showCurrentMovement: boolean
  showNextMovement: boolean
  showControls: boolean
  showProgress: boolean
  showCompletedCard: boolean
  showWorkoutSummary: boolean
  showRoundCounter: boolean
}

const defaultConfig: TimerLayoutConfig = {
  showTimerBlock: true,
  showCurrentMovement: false,
  showNextMovement: false,
  showControls: true,
  showProgress: false,
  showCompletedCard: false,
  showWorkoutSummary: true,
  showRoundCounter: true
}

const layoutConfigs: Record<WorkoutType, Partial<TimerLayoutConfig>> = {
  // All timer types show all blocks
  rest: {},
  custom: {},
  stopwatch: {},
  amrap: {},
  for_time: {},
  tabata: {},
  intervals: {},
  emom: {},
  work_rest: {}
}

export function getTimerLayoutConfig(workoutType: WorkoutType): TimerLayoutConfig {
  const typeConfig = layoutConfigs[workoutType] || {}
  return { ...defaultConfig, ...typeConfig }
}

export function isBlockVisible(
  workoutType: WorkoutType,
  blockName: keyof TimerLayoutConfig
): boolean {
  const config = getTimerLayoutConfig(workoutType)
  return config[blockName]
}
