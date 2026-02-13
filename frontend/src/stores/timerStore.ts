import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { TimerConfig } from '@/types/workout'

export const TimerState = {
  IDLE: 'idle',
  PREPARING: 'preparing',
  RUNNING: 'running',
  PAUSED: 'paused',
  COMPLETED: 'completed',
} as const

export type TimerState = typeof TimerState[keyof typeof TimerState]

// Manual round tracking for AMRAP, stopwatch, for_time timers
export interface ManualRound {
  roundNumber: number
  completedAt: number // elapsed seconds when round was completed
  duration: number // seconds this round took
}

export const useTimerStore = defineStore('timer', () => {
  // Core timer state
  const state = ref<TimerState>(TimerState.IDLE)
  const currentTime = ref(0)
  const intervalTime = ref(0)
  const config = ref<TimerConfig | null>(null)
  const currentRound = ref(1)
  const currentIntervalIndex = ref(0)
  const prepTime = ref(0)
  const prepDuration = ref(5)
  const autoStart = ref(false)
  const skipPreparation = ref(false)

  // Work & Rest timer state
  const workRestPhase = ref<'work' | 'rest'>('work')
  const workRestWorkDuration = ref(0)
  const workRestRestTime = ref(0)

  // Repeat interval state (for "until failure" workouts)
  const repeatRound = ref(1)
  const repeatWorkRound = ref(0)
  const repeatRestRound = ref(0)

  // Manual round counter state
  const manualRounds = ref<ManualRound[]>([])

  const isRunning = computed(() => state.value === TimerState.RUNNING)
  const isPreparing = computed(() => state.value === TimerState.PREPARING)
  const isPaused = computed(() => state.value === TimerState.PAUSED)
  const isCompleted = computed(() => state.value === TimerState.COMPLETED)

  const isIntervalBased = computed(() => {
    const intervalTypes = ['intervals', 'tabata', 'emom', 'custom']
    return intervalTypes.includes(config.value?.type || '') &&
      config.value?.intervals &&
      config.value.intervals.length > 0
  })

  const isWorkRestTimer = computed(() => config.value?.type === 'work_rest')

  const progress = computed(() => {
    if (!config.value?.total_seconds) return 0
    return (currentTime.value / config.value.total_seconds) * 100
  })

  const currentInterval = computed(() => {
    if (!config.value?.intervals.length) return null
    return config.value.intervals[currentIntervalIndex.value] || null
  })

  const totalIntervals = computed(() => config.value?.intervals?.length || 0)

  // Check if current interval is open-ended (duration: 0)
  const isOpenEndedInterval = computed(() => {
    return currentInterval.value?.duration === 0
  })

  const setConfig = (timerConfig: TimerConfig, options?: { autoStart?: boolean; skipPreparation?: boolean; prepDuration?: number }) => {
    config.value = timerConfig
    currentTime.value = 0
    intervalTime.value = 0
    currentRound.value = 1
    currentIntervalIndex.value = 0
    prepTime.value = 0
    prepDuration.value = options?.prepDuration ?? 5
    state.value = TimerState.IDLE
    autoStart.value = options?.autoStart ?? false
    skipPreparation.value = options?.skipPreparation ?? false
    // Reset work_rest state
    workRestPhase.value = 'work'
    workRestWorkDuration.value = 0
    workRestRestTime.value = 0
    // Reset repeat state
    repeatRound.value = 1
    repeatWorkRound.value = 0
    repeatRestRound.value = 0
    // Reset manual rounds
    manualRounds.value = []
  }

  const clearAutoStart = () => {
    autoStart.value = false
    skipPreparation.value = false
  }

  const start = (skipPreparation: boolean = false) => {
    if (state.value === TimerState.IDLE) {
      if (skipPreparation) {
        // Start immediately without preparation countdown
        state.value = TimerState.RUNNING
      } else {
        // Start preparation countdown
        state.value = TimerState.PREPARING
        prepTime.value = 0
      }
    } else if (state.value === TimerState.PAUSED) {
      // Resume from pause - check if we were preparing or running
      // If prepTime < prepDuration, we were still in preparation (including prepTime === 0)
      // If prepTime >= prepDuration, preparation was complete, so resume running
      if (prepTime.value < prepDuration.value) {
        state.value = TimerState.PREPARING
      } else {
        state.value = TimerState.RUNNING
      }
    }
  }

  const startWorkout = () => {
    // Called when preparation is complete
    state.value = TimerState.RUNNING
  }

  const pause = () => {
    if (state.value === TimerState.RUNNING || state.value === TimerState.PREPARING) {
      state.value = TimerState.PAUSED
    }
  }

  const reset = () => {
    currentTime.value = 0
    intervalTime.value = 0
    currentRound.value = 1
    currentIntervalIndex.value = 0
    prepTime.value = 0
    state.value = TimerState.IDLE
    // Reset work_rest state
    workRestPhase.value = 'work'
    workRestWorkDuration.value = 0
    workRestRestTime.value = 0
    // Reset repeat state
    repeatRound.value = 1
    repeatWorkRound.value = 0
    repeatRestRound.value = 0
    // Reset manual rounds
    manualRounds.value = []
  }

  const incrementPrepTime = () => {
    prepTime.value++
  }

  const incrementIntervalTime = () => {
    intervalTime.value++
  }

  const resetIntervalTime = () => {
    intervalTime.value = 0
  }

  const complete = () => {
    state.value = TimerState.COMPLETED
  }

  const incrementTime = () => {
    currentTime.value++
  }

  const nextInterval = () => {
    if (config.value?.intervals && currentIntervalIndex.value < config.value.intervals.length - 1) {
      currentIntervalIndex.value++
    }
  }

  const nextRound = () => {
    if (config.value?.rounds && currentRound.value < config.value.rounds) {
      currentRound.value++
      currentIntervalIndex.value = 0
    }
  }

  const incrementRepeatRound = () => {
    repeatRound.value++
  }

  const incrementRepeatWorkRound = () => {
    repeatWorkRound.value++
  }

  const incrementRepeatRestRound = () => {
    repeatRestRound.value++
  }

  // Manual round counter methods
  const addManualRound = () => {
    const completedAt = currentTime.value
    const lastRound = manualRounds.value[manualRounds.value.length - 1]
    const previousTime = lastRound ? lastRound.completedAt : 0
    const duration = completedAt - previousTime

    manualRounds.value.push({
      roundNumber: manualRounds.value.length + 1,
      completedAt,
      duration
    })
  }

  // Work & Rest timer methods
  const startWorkRestRest = () => {
    // Store current work time as rest duration
    workRestWorkDuration.value = intervalTime.value
    workRestRestTime.value = intervalTime.value
    workRestPhase.value = 'rest'
    intervalTime.value = 0
  }

  const decrementWorkRestRestTime = () => {
    if (workRestRestTime.value > 0) {
      workRestRestTime.value--
    }
  }

  const startNextWorkRestRound = () => {
    if (config.value?.rounds && currentRound.value < config.value.rounds) {
      currentRound.value++
      workRestPhase.value = 'work'
      intervalTime.value = 0
      workRestWorkDuration.value = 0
      workRestRestTime.value = 0
    }
  }

  return {
    state,
    currentTime,
    intervalTime,
    config,
    currentRound,
    currentIntervalIndex,
    prepTime,
    prepDuration,
    autoStart,
    skipPreparation,
    isRunning,
    isPreparing,
    isPaused,
    isCompleted,
    isIntervalBased,
    isWorkRestTimer,
    progress,
    currentInterval,
    totalIntervals,
    isOpenEndedInterval,
    // Work & Rest state
    workRestPhase,
    workRestWorkDuration,
    workRestRestTime,
    setConfig,
    start,
    startWorkout,
    pause,
    reset,
    complete,
    incrementTime,
    incrementIntervalTime,
    resetIntervalTime,
    incrementPrepTime,
    nextInterval,
    nextRound,
    clearAutoStart,
    // Work & Rest methods
    startWorkRestRest,
    decrementWorkRestRestTime,
    startNextWorkRestRound,
    // Repeat interval state
    repeatRound,
    repeatWorkRound,
    repeatRestRound,
    incrementRepeatRound,
    incrementRepeatWorkRound,
    incrementRepeatRestRound,
    // Manual round counter
    manualRounds,
    addManualRound,
  }
})
