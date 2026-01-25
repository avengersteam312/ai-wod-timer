<script setup lang="ts">
import { computed } from 'vue'
import { useWorkoutStore } from '@/stores/workoutStore'
import { useTimerStore } from '@/stores/timerStore'
import { storeToRefs } from 'pinia'

const workoutStore = useWorkoutStore()
const timerStore = useTimerStore()
const { currentWorkout } = storeToRefs(workoutStore)
const { currentInterval, isCompleted, isRunning, isPaused, isWorkRestTimer, workRestPhase, currentRound } = storeToRefs(timerStore)

// Check if this is a work_rest timer
const isWorkRest = computed(() => isWorkRestTimer.value)

// Count work and rest intervals from the workout config (for interval-based timers)
const totalWorkRounds = computed(() => {
  if (isWorkRest.value) {
    return currentWorkout.value?.timer_config?.rounds ?? 0
  }
  if (!currentWorkout.value?.timer_config?.intervals) return 0
  return currentWorkout.value.timer_config.intervals.filter(i => i.type === 'work').length
})

const totalRestRounds = computed(() => {
  if (isWorkRest.value) {
    return currentWorkout.value?.timer_config?.rounds ?? 0
  }
  if (!currentWorkout.value?.timer_config?.intervals) return 0
  return currentWorkout.value.timer_config.intervals.filter(i => i.type === 'rest').length
})

// Calculate completed work and rest rounds based on current interval index
const completedWorkRounds = computed(() => {
  if (isWorkRest.value) {
    if (isCompleted.value) return totalWorkRounds.value
    // For work_rest, currentRound tracks the round, work phase means in progress
    if (workRestPhase.value === 'work') {
      return currentRound.value - 1
    }
    return currentRound.value
  }

  if (!currentWorkout.value?.timer_config?.intervals) return 0
  if (isCompleted.value) return totalWorkRounds.value

  const intervals = currentWorkout.value.timer_config.intervals
  let workCount = 0

  for (let i = 0; i < timerStore.currentIntervalIndex; i++) {
    if (intervals[i]?.type === 'work') {
      workCount++
    }
  }

  return workCount
})

const completedRestRounds = computed(() => {
  if (isWorkRest.value) {
    if (isCompleted.value) return totalRestRounds.value
    // For work_rest, rest phase means in progress
    if (workRestPhase.value === 'rest') {
      return currentRound.value - 1
    }
    return currentRound.value - 1
  }

  if (!currentWorkout.value?.timer_config?.intervals) return 0
  if (isCompleted.value) return totalRestRounds.value

  const intervals = currentWorkout.value.timer_config.intervals
  let restCount = 0

  for (let i = 0; i < timerStore.currentIntervalIndex; i++) {
    if (intervals[i]?.type === 'rest') {
      restCount++
    }
  }

  return restCount
})

// Check if timer has started (running or paused)
const hasStarted = computed(() => isRunning.value || isPaused.value || isCompleted.value)

// Current phase (work or rest)
const isWorkPhase = computed(() => {
  if (isWorkRest.value) return workRestPhase.value === 'work'
  return currentInterval.value?.type === 'work'
})
const isRestPhase = computed(() => {
  if (isWorkRest.value) return workRestPhase.value === 'rest'
  return currentInterval.value?.type === 'rest'
})

// Current round numbers (0 before start, then 1-indexed after start)
const currentWorkRound = computed(() => {
  if (!hasStarted.value) return 0
  if (isCompleted.value) return totalWorkRounds.value
  return isWorkPhase.value ? completedWorkRounds.value + 1 : completedWorkRounds.value
})

const currentRestRound = computed(() => {
  if (!hasStarted.value) return 0
  if (isCompleted.value) return totalRestRounds.value
  return isRestPhase.value ? completedRestRounds.value + 1 : completedRestRounds.value
})

// Show for interval-based (2+ intervals) or work_rest timers
const shouldShow = computed(() => {
  if (isWorkRest.value) return true
  return (currentWorkout.value?.timer_config?.intervals?.length ?? 0) >= 2
})
</script>

<template>
  <div v-if="shouldShow" class="bg-surface rounded-xl p-4">
    <div class="flex justify-around">
      <!-- Work Rounds -->
      <div
        class="text-xl font-bold font-athletic transition-colors"
        :class="isWorkPhase ? 'text-timer-work' : 'text-foreground'"
      >
        ROUND {{ currentWorkRound }}/{{ totalWorkRounds }}
      </div>

      <!-- Divider -->
      <div class="w-px bg-border"></div>

      <!-- Rest Rounds -->
      <div
        class="text-xl font-bold font-athletic transition-colors"
        :class="isRestPhase ? 'text-timer-rest' : 'text-foreground'"
      >
        REST {{ currentRestRound }}/{{ totalRestRounds }}
      </div>
    </div>
  </div>
</template>
