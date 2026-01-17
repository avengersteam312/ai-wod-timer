import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { TimerConfig, AudioCue } from '@/types/workout'

export enum TimerState {
  IDLE = 'idle',
  PREPARING = 'preparing',
  RUNNING = 'running',
  PAUSED = 'paused',
  COMPLETED = 'completed',
}

export const useTimerStore = defineStore('timer', () => {
  const state = ref<TimerState>(TimerState.IDLE)
  const currentTime = ref(0) // Total elapsed time
  const intervalTime = ref(0) // Time within current interval
  const config = ref<TimerConfig | null>(null)
  const currentRound = ref(1)
  const currentIntervalIndex = ref(0)
  const prepTime = ref(0) // Countdown preparation time
  const prepDuration = ref(5) // 5 seconds to get ready

  const isRunning = computed(() => state.value === TimerState.RUNNING)
  const isPreparing = computed(() => state.value === TimerState.PREPARING)
  const isPaused = computed(() => state.value === TimerState.PAUSED)
  const isCompleted = computed(() => state.value === TimerState.COMPLETED)

  const isIntervalBased = computed(() =>
    config.value?.type === 'intervals' &&
    config.value?.intervals &&
    config.value.intervals.length > 0
  )

  const progress = computed(() => {
    if (!config.value?.total_seconds) return 0
    return (currentTime.value / config.value.total_seconds) * 100
  })

  const currentInterval = computed(() => {
    if (!config.value?.intervals.length) return null
    return config.value.intervals[currentIntervalIndex.value] || null
  })

  const totalIntervals = computed(() => config.value?.intervals?.length || 0)

  const setConfig = (timerConfig: TimerConfig) => {
    config.value = timerConfig
    currentTime.value = 0
    intervalTime.value = 0
    currentRound.value = 1
    currentIntervalIndex.value = 0
    prepTime.value = 0
    state.value = TimerState.IDLE
  }

  const start = () => {
    if (state.value === TimerState.IDLE) {
      // Start preparation countdown
      state.value = TimerState.PREPARING
      prepTime.value = 0
    } else if (state.value === TimerState.PAUSED) {
      // Resume from pause
      state.value = TimerState.RUNNING
    }
  }

  const startWorkout = () => {
    // Called when preparation is complete
    state.value = TimerState.RUNNING
  }

  const pause = () => {
    if (state.value === TimerState.RUNNING) {
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

  return {
    state,
    currentTime,
    intervalTime,
    config,
    currentRound,
    currentIntervalIndex,
    prepTime,
    prepDuration,
    isRunning,
    isPreparing,
    isPaused,
    isCompleted,
    isIntervalBased,
    progress,
    currentInterval,
    totalIntervals,
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
  }
})
