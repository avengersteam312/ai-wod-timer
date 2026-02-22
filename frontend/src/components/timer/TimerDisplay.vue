<script setup lang="ts">
import { computed, ref, watch, onUnmounted } from 'vue'
import { useTimerStore, TimerState } from '@/stores/timerStore'
import { useWorkoutStore } from '@/stores/workoutStore'
import { storeToRefs } from 'pinia'
import { formatTimeDetailed, formatTime } from '@/lib/utils'

const timerStore = useTimerStore()
const workoutStore = useWorkoutStore()
const { currentTime, intervalTime, config, isCompleted, isPreparing, prepTime, prepDuration, isIntervalBased, currentInterval, isWorkRestTimer, workRestPhase, workRestRestTime, workRestWorkDuration, state, isRunning, isPaused } = storeToRefs(timerStore)
const { currentWorkout } = storeToRefs(workoutStore)

// Check if RoundCounterBlock would be shown (to avoid duplicate counters)
const hasRoundCounterBlock = computed(() => {
  if (isWorkRestTimer.value) return true
  const intervals = currentWorkout.value?.timer_config?.intervals
  if (!intervals) return false
  // RoundCounterBlock shows for 2+ intervals or any repeat interval
  const hasRepeat = intervals.some(i => i.repeat)
  return hasRepeat || intervals.length >= 2
})

// Check if manual round counter is active (can add rounds by tapping)
const canAddManualRound = computed(() => {
  const type = currentWorkout.value?.workout_type
  if (!type) return false
  // Don't show if RoundCounterBlock is already showing
  if (hasRoundCounterBlock.value) return false
  // Don't show for rest timer (no rounds concept)
  if (type === 'rest') return false
  // Allow for all other workout types without predefined rounds
  return true
})

// Check if timer is active (running or paused but started)
const isTimerActive = computed(() => {
  return (isRunning.value || isPaused.value) && !isCompleted.value
})

// Show tap indicator when manual rounds are available and timer is active
const showTapIndicator = computed(() => {
  return canAddManualRound.value && isTimerActive.value
})

// Handle tap to add round
const handleTimerTap = () => {
  if (canAddManualRound.value && isRunning.value && !isCompleted.value) {
    timerStore.addManualRound()
  }
}

// Smooth progress interpolation
const smoothProgress = ref(0)
let animationFrameId: number | null = null
let lastTimestamp = 0
let baseProgress = 0

const updateSmoothProgress = (timestamp: number) => {
  if (state.value !== TimerState.RUNNING && state.value !== TimerState.PREPARING) {
    smoothProgress.value = baseProgress
    return
  }

  const elapsed = (timestamp - lastTimestamp) / 1000 // seconds since last update

  // Calculate progress increment per second based on timer type
  let progressPerSecond = 0

  if (state.value === TimerState.PREPARING) {
    // Preparation countdown - progress decreases
    progressPerSecond = -(100 / prepDuration.value)
  } else if (isWorkRestTimer.value && workRestPhase.value === 'rest' && workRestWorkDuration.value > 0) {
    // Work & Rest timer rest phase - progress increases as rest time decreases
    progressPerSecond = 100 / workRestWorkDuration.value
  } else if (isIntervalBased.value && currentInterval.value && currentInterval.value.duration > 0) {
    progressPerSecond = 100 / currentInterval.value.duration
  } else if (config.value?.total_seconds) {
    progressPerSecond = 100 / config.value.total_seconds
  }

  const newProgress = baseProgress + (elapsed * progressPerSecond)
  smoothProgress.value = Math.max(0, Math.min(100, newProgress))
  animationFrameId = requestAnimationFrame(updateSmoothProgress)
}

// Sync base progress when timer values change
watch([currentTime, intervalTime, prepTime, workRestRestTime, workRestPhase, state], () => {
  if (state.value === TimerState.PREPARING) {
    // Preparation countdown - progress starts at 100% and decreases
    baseProgress = ((prepDuration.value - prepTime.value) / prepDuration.value) * 100
    smoothProgress.value = baseProgress
    lastTimestamp = performance.now()

    if (!animationFrameId) {
      animationFrameId = requestAnimationFrame(updateSmoothProgress)
    }
  } else if (state.value === TimerState.RUNNING) {
    // Calculate base progress from current timer state
    if (isWorkRestTimer.value && workRestPhase.value === 'rest' && workRestWorkDuration.value > 0) {
      // Work & Rest timer rest phase - progress based on rest time remaining
      baseProgress = ((workRestWorkDuration.value - workRestRestTime.value) / workRestWorkDuration.value) * 100
    } else if (isIntervalBased.value && currentInterval.value && currentInterval.value.duration > 0) {
      baseProgress = (intervalTime.value / currentInterval.value.duration) * 100
    } else if (config.value?.total_seconds) {
      baseProgress = (currentTime.value / config.value.total_seconds) * 100
    } else {
      baseProgress = 0
    }
    smoothProgress.value = baseProgress
    lastTimestamp = performance.now()

    if (!animationFrameId) {
      animationFrameId = requestAnimationFrame(updateSmoothProgress)
    }
  } else {
    if (animationFrameId) {
      cancelAnimationFrame(animationFrameId)
      animationFrameId = null
    }
  }
}, { immediate: true })

onUnmounted(() => {
  if (animationFrameId) {
    cancelAnimationFrame(animationFrameId)
  }
})

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
    // Open-ended interval (duration: 0) - count up like stopwatch
    if (currentInterval.value.duration === 0) {
      return formatTimeDetailed(intervalTime.value)
    }
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
    // Open-ended interval (duration: 0) - no warning state
    if (currentInterval.value.duration === 0) {
      if (currentInterval.value.type === 'rest') return 'rest'
      return 'work'
    }
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
  if (isCompleted.value) return 'DONE'

  // Work & Rest timer
  if (isWorkRestTimer.value) {
    return workRestPhase.value === 'work' ? 'WORK' : 'REST'
  }

  if (isIntervalBased.value && currentInterval.value) {
    return currentInterval.value.type === 'rest' ? 'REST' : 'WORK'
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
    // Open-ended interval (duration: 0) - no progress ring
    if (currentInterval.value.duration === 0) {
      return 0
    }
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
  // Use smooth interpolated progress when running or preparing, otherwise use stepped progress
  const isAnimating = state.value === TimerState.RUNNING || state.value === TimerState.PREPARING
  const progress = isAnimating ? smoothProgress.value : ringProgress.value
  return circumference - (progress / 100) * circumference
})

const totalTimeDisplay = computed(() => {
  // Only show total time when it differs from main display
  // (i.e., for interval-based timers where main shows interval time)

  // Work & Rest timer - show total elapsed time
  if (isWorkRestTimer.value) {
    return `Total: ${formatTimeDetailed(currentTime.value)}`
  }

  // Interval-based timers - show total when main shows interval time
  if (isIntervalBased.value && currentInterval.value) {
    return `Total: ${formatTimeDetailed(currentTime.value)}`
  }

  // Stopwatch, for_time, amrap - main timer IS the total, don't show duplicate
  return null
})
</script>

<template>
  <div class="flex flex-col items-center justify-center">
    <!-- Timer with Circular Progress Ring -->
    <div
      class="relative flex items-center justify-center"
      :class="{ 'cursor-pointer': showTapIndicator }"
      :style="{ width: `${ringSize}px`, height: `${ringSize}px` }"
      @click="handleTimerTap"
    >
      <!-- Tap indicator - multiple pulsing rings -->
      <template v-if="showTapIndicator">
        <div
          class="absolute rounded-full animate-ripple-1 border-2"
          :class="ringColorClass.replace('stroke-', 'border-')"
          :style="{ width: `${ringSize + 16}px`, height: `${ringSize + 16}px` }"
        />
        <div
          class="absolute rounded-full animate-ripple-2 border-2"
          :class="ringColorClass.replace('stroke-', 'border-')"
          :style="{ width: `${ringSize + 16}px`, height: `${ringSize + 16}px` }"
        />
        <div
          class="absolute rounded-full animate-ripple-3 border-2"
          :class="ringColorClass.replace('stroke-', 'border-')"
          :style="{ width: `${ringSize + 16}px`, height: `${ringSize + 16}px` }"
        />
      </template>

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
        />
      </svg>

      <!-- Timer Content (inside ring) -->
      <div class="absolute flex flex-col items-center justify-center text-center">
        <!-- Interval Label -->
        <div v-if="displayLabel" :class="['text-xl font-bold mb-1', labelColorClass]">
          {{ displayLabel }}
        </div>

        <!-- Main Timer Display -->
        <div :class="['text-6xl font-bold tabular-nums tracking-tight', timeClass]">
          {{ displayTime }}
        </div>

        <!-- Total Time or Tap Hint -->
        <div v-if="totalTimeDisplay && !isPreparing" class="text-xs text-muted-foreground mt-1">
          {{ totalTimeDisplay }}
        </div>
        <div v-else-if="showTapIndicator" class="text-xs text-muted-foreground mt-1">
          tap to count round
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
@keyframes ripple {
  0% {
    transform: scale(1);
    opacity: 0.4;
  }
  100% {
    transform: scale(1.15);
    opacity: 0;
  }
}

.animate-ripple-1 {
  animation: ripple 2s ease-out infinite;
}

.animate-ripple-2 {
  animation: ripple 2s ease-out infinite;
  animation-delay: 0.6s;
}

.animate-ripple-3 {
  animation: ripple 2s ease-out infinite;
  animation-delay: 1.2s;
}
</style>
