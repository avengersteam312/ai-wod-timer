<script setup lang="ts">
import { computed } from 'vue'
import { useTimerStore } from '@/stores/timerStore'
import { storeToRefs } from 'pinia'
import { formatTimeDetailed, formatTime } from '@/lib/utils'

const timerStore = useTimerStore()
const { currentTime, intervalTime, config, isCompleted, isPreparing, prepTime, prepDuration, isIntervalBased, currentInterval, currentIntervalIndex, isWorkRestTimer, workRestPhase, workRestRestTime, workRestWorkDuration, currentRound } = storeToRefs(timerStore)

const displayTime = computed(() => {
  if (isPreparing.value) {
    const remaining = prepDuration.value - prepTime.value
    return remaining.toString()
  }

  // Work & Rest timer
  if (isWorkRestTimer.value) {
    if (workRestPhase.value === 'work') {
      // Work phase - count up
      return formatTimeDetailed(intervalTime.value)
    } else {
      // Rest phase - count down
      return formatTimeDetailed(workRestRestTime.value)
    }
  }

  if (isIntervalBased.value && currentInterval.value) {
    const remaining = currentInterval.value.duration - intervalTime.value
    return formatTime(remaining)
  }

  // Countdown timers: countdown, amrap (count down from total to 0)
  const countdownTypes = ['countdown', 'amrap']
  if (countdownTypes.includes(config.value?.type || '') && config.value?.total_seconds) {
    return formatTimeDetailed(Math.max(0, config.value.total_seconds - currentTime.value))
  }
  // For Time and others: count up from 0
  return formatTimeDetailed(currentTime.value)
})

// Determine current state for styling
const timerState = computed(() => {
  if (isPreparing.value) return 'preparing'
  if (isCompleted.value) return 'complete'

  // Work & Rest timer
  if (isWorkRestTimer.value) {
    if (workRestPhase.value === 'rest') {
      if (workRestRestTime.value <= 3) return 'warning'
      return 'rest'
    }
    return 'work'
  }

  if (isIntervalBased.value && currentInterval.value) {
    const remaining = currentInterval.value.duration - intervalTime.value
    if (remaining <= 3) return 'warning'
    if (currentInterval.value.type === 'rest') return 'rest'
    return 'work'
  }

  if (config.value?.total_seconds) {
    const remaining = config.value.total_seconds - currentTime.value
    if (remaining <= 10) return 'warning'
    if (remaining <= 30) return 'work'
  }

  return 'work'
})

const ringColorClass = computed(() => {
  const stateColors: Record<string, string> = {
    preparing: 'stroke-timer-preparing',
    complete: 'stroke-timer-complete',
    warning: 'stroke-timer-warning',
    rest: 'stroke-timer-rest',
    work: 'stroke-timer-work'
  }
  return stateColors[timerState.value] || 'stroke-timer-work'
})

const labelColorClass = computed(() => {
  const stateColors: Record<string, string> = {
    preparing: 'text-timer-preparing',
    complete: 'text-timer-complete',
    warning: 'text-timer-warning',
    rest: 'text-timer-rest',
    work: 'text-timer-work'
  }
  return stateColors[timerState.value] || 'text-timer-work'
})

const timeClass = computed(() => {
  if (timerState.value === 'preparing' || timerState.value === 'warning') {
    return `${labelColorClass.value} animate-pulse`
  }
  if (timerState.value === 'complete') {
    return labelColorClass.value
  }
  return 'text-foreground'
})

const displayLabel = computed(() => {
  if (isPreparing.value) return 'GET READY'
  if (isCompleted.value) return 'WORKOUT COMPLETE'

  // Work & Rest timer
  if (isWorkRestTimer.value) {
    const phase = workRestPhase.value === 'work' ? 'Work' : 'Rest'
    return `Round ${currentRound.value} - ${phase}`
  }

  if (isIntervalBased.value && currentInterval.value) {
    const isRest = currentInterval.value.type === 'rest'

    // Count only work rounds up to and including current index
    const intervals = timerStore.config?.intervals || []
    let workRoundNum = 0
    for (let i = 0; i <= currentIntervalIndex.value; i++) {
      if (intervals[i]?.type === 'work') {
        workRoundNum++
      }
    }

    // For EMOM (no rest intervals), just show "Round X"
    const hasRestIntervals = intervals.some(i => i.type === 'rest')
    if (!hasRestIntervals) {
      return `Round ${workRoundNum}`
    }

    // For timers with work/rest, show "Round X - Work" or "Round X - Rest"
    const type = isRest ? 'Rest' : 'Work'
    return `Round ${workRoundNum} - ${type}`
  }

  return null
})

// Progress for the circular ring (0-100)
const ringProgress = computed(() => {
  if (isPreparing.value) {
    return ((prepDuration.value - prepTime.value) / prepDuration.value) * 100
  }

  // Work & Rest timer
  if (isWorkRestTimer.value) {
    if (workRestPhase.value === 'rest' && workRestWorkDuration.value > 0) {
      // Rest phase - show progress as rest time elapsed
      return ((workRestWorkDuration.value - workRestRestTime.value) / workRestWorkDuration.value) * 100
    }
    // Work phase - no progress ring (indeterminate)
    return 0
  }

  if (isIntervalBased.value && currentInterval.value) {
    return (intervalTime.value / currentInterval.value.duration) * 100
  }

  if (config.value?.total_seconds) {
    return timerStore.progress
  }

  return 0
})

// SVG circle calculations
const ringSize = 200
const strokeWidth = 8
const radius = (ringSize - strokeWidth) / 2
const circumference = 2 * Math.PI * radius

const strokeDashoffset = computed(() => {
  return circumference - (ringProgress.value / 100) * circumference
})

const totalTimeDisplay = computed(() => {
  // Work & Rest timer - show total elapsed time
  if (isWorkRestTimer.value) {
    return `Total: ${formatTimeDetailed(currentTime.value)}`
  }

  if (!config.value?.total_seconds) return ''
  // Don't show "remaining" for countdown-style timers (they already show remaining time)
  const countdownTypes = ['countdown', 'amrap']
  if (countdownTypes.includes(config.value.type)) return ''
  const remaining = config.value.total_seconds - currentTime.value
  return `${formatTime(remaining)} remaining`
})
</script>

<template>
  <div class="flex flex-col items-center justify-center">
    <!-- Timer with Circular Progress Ring -->
    <div class="relative flex items-center justify-center" :style="{ width: `${ringSize}px`, height: `${ringSize}px` }">
      <!-- Background Ring -->
      <svg
        :width="ringSize"
        :height="ringSize"
        class="absolute transform -rotate-90"
      >
        <circle
          :cx="ringSize / 2"
          :cy="ringSize / 2"
          :r="radius"
          fill="none"
          class="stroke-surface-elevated"
          :stroke-width="strokeWidth"
        />
        <!-- Progress Ring -->
        <circle
          :cx="ringSize / 2"
          :cy="ringSize / 2"
          :r="radius"
          fill="none"
          :class="ringColorClass"
          :stroke-width="strokeWidth"
          stroke-linecap="round"
          :stroke-dasharray="circumference"
          :stroke-dashoffset="strokeDashoffset"
          class="transition-all duration-300 ease-linear"
        />
      </svg>

      <!-- Timer Content (inside ring) -->
      <div class="absolute flex flex-col items-center justify-center text-center">
        <!-- Interval Label -->
        <div v-if="displayLabel" :class="['text-sm font-medium mb-1', labelColorClass]">
          {{ displayLabel }}
        </div>

        <!-- Main Timer Display -->
        <div :class="['text-6xl font-bold tabular-nums tracking-tight', timeClass]">
          {{ displayTime }}
        </div>

        <!-- Total Time Remaining -->
        <div v-if="totalTimeDisplay && !isPreparing && !isCompleted" class="text-xs text-muted-foreground mt-1">
          {{ totalTimeDisplay }}
        </div>

        <div v-if="isCompleted" class="text-xs text-muted-foreground mt-1">
          Great job!
        </div>
      </div>
    </div>
  </div>
</template>
