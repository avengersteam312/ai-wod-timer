<script setup lang="ts">
import { computed } from 'vue'
import { useTimerStore, TimerState } from '@/stores/timerStore'
import { storeToRefs } from 'pinia'
import { useTimer } from '@/composables/useTimer'
import { Play, Pause, RotateCcw, Check, Coffee, Dumbbell, Square } from 'lucide-vue-next'

const timerStore = useTimerStore()
const { state, isCompleted, currentInterval, currentIntervalIndex, config, skipPreparation, isWorkRestTimer, workRestPhase, isIntervalBased } = storeToRefs(timerStore)
const { startTimer, pauseTimer, resetTimer, triggerWorkRestRest, skipToNextInterval } = useTimer()

const handleStartPause = () => {
  // Disable pause during countdown - use reset instead
  if (state.value === TimerState.PREPARING) {
    // During countdown, reset instead of pause for better UX
    resetTimer()
    return
  }
  
  if (state.value === TimerState.RUNNING) {
    pauseTimer()
  } else {
    startTimer(skipPreparation.value)
  }
}

const isActive = computed(() =>
  state.value === TimerState.RUNNING
)

const isPreparing = computed(() =>
  state.value === TimerState.PREPARING
)

// Reset button is only enabled when timer has started (not idle)
const resetButtonEnabled = computed(() =>
  state.value !== TimerState.IDLE
)

// Show Done button for work_rest timer during work phase while running
const showDoneButton = computed(() =>
  isWorkRestTimer.value && workRestPhase.value === 'work' && state.value === TimerState.RUNNING
)

// Check if there are any rest intervals
const hasRestIntervals = computed(() => {
  const intervals = config.value?.intervals
  if (!intervals || intervals.length === 0) return false
  return intervals.some(interval => interval.type === 'rest')
})

// Show skip to next interval button only if there are rest intervals (otherwise show stop button)
const showSkipButton = computed(() =>
  isIntervalBased.value && !isWorkRestTimer.value && hasRestIntervals.value
)

// Skip button is only enabled when running or paused
const skipButtonEnabled = computed(() =>
  state.value === TimerState.RUNNING || state.value === TimerState.PAUSED
)

// Next interval type (to determine which icon to show)
const nextIntervalIsRest = computed(() => {
  const intervals = config.value?.intervals
  if (!intervals || intervals.length === 0) return false

  const nextIndex = currentIntervalIndex.value + 1
  if (nextIndex >= intervals.length) {
    // No next interval - show stop/complete icon behavior
    return false
  }

  return intervals[nextIndex].type === 'rest'
})

// End button is only enabled when running or paused
const endButtonEnabled = computed(() =>
  state.value === TimerState.RUNNING || state.value === TimerState.PAUSED
)

// End the timer manually
const endTimer = () => {
  if (!endButtonEnabled.value) return
  timerStore.complete()
}

// Determine primary button color based on state
const primaryButtonClass = computed(() => {
  if (isCompleted.value) return 'bg-timer-complete hover:bg-timer-complete/90'
  if (currentInterval.value?.type === 'rest') return 'bg-timer-rest hover:bg-timer-rest/90'
  if (isWorkRestTimer.value && workRestPhase.value === 'rest') return 'bg-timer-rest hover:bg-timer-rest/90'
  return 'bg-timer-work hover:bg-timer-work/90'
})
</script>

<template>
  <div class="flex items-center justify-center gap-6">
    <!-- Reset Button (Secondary - 48px) -->
    <button
      @click="resetTimer"
      :disabled="!resetButtonEnabled"
      :class="[
        'w-12 h-12 rounded-full bg-surface-elevated border border-muted-foreground/40 flex items-center justify-center transition-colors',
        resetButtonEnabled ? 'hover:bg-surface-elevated/80 hover:border-muted-foreground/60' : 'opacity-50 cursor-not-allowed'
      ]"
      aria-label="Reset"
    >
      <RotateCcw class="h-5 w-5 text-foreground" />
    </button>

    <!-- Play/Pause Button (Primary - 72px) -->
    <!-- During countdown, clicking resets instead of pausing -->
    <button
      @click="handleStartPause"
      :disabled="isPreparing"
      :class="[
        'w-[72px] h-[72px] rounded-full flex items-center justify-center transition-colors',
        primaryButtonClass,
        isPreparing ? 'opacity-50 cursor-not-allowed' : ''
      ]"
      :aria-label="isPreparing ? 'Reset countdown' : 'Play/Pause'"
    >
      <Check v-if="isCompleted" class="h-8 w-8 text-background" />
      <Pause v-else-if="isActive" class="h-8 w-8 text-background" />
      <Play v-else class="h-8 w-8 text-background ml-1" />
    </button>

    <!-- Done Button for Work & Rest timer (during work phase) -->
    <button
      v-if="showDoneButton"
      @click="triggerWorkRestRest"
      class="w-12 h-12 rounded-full bg-surface-elevated border border-timer-rest/60 hover:border-timer-rest flex items-center justify-center transition-colors"
      aria-label="Done - Start Rest"
    >
      <Coffee class="h-5 w-5 text-timer-rest" />
    </button>

    <!-- Skip to Next Interval Button for interval-based timers -->
    <button
      v-else-if="showSkipButton"
      @click="skipToNextInterval"
      :disabled="!skipButtonEnabled"
      :class="[
        'w-12 h-12 rounded-full bg-surface-elevated flex items-center justify-center transition-colors',
        nextIntervalIsRest ? 'border border-timer-rest/60' : 'border border-timer-work/60',
        skipButtonEnabled
          ? (nextIntervalIsRest ? 'hover:border-timer-rest' : 'hover:border-timer-work')
          : 'opacity-50 cursor-not-allowed'
      ]"
      :aria-label="nextIntervalIsRest ? 'Skip to Rest' : 'Skip to Work'"
    >
      <Coffee v-if="nextIntervalIsRest" class="h-5 w-5 text-timer-rest" />
      <Dumbbell v-else class="h-5 w-5 text-timer-work" />
    </button>

    <!-- End Timer Button -->
    <button
      v-else
      @click="endTimer"
      :disabled="!endButtonEnabled"
      :class="[
        'w-12 h-12 rounded-full bg-surface-elevated border border-red-500/60 flex items-center justify-center transition-colors',
        endButtonEnabled ? 'hover:border-red-500' : 'opacity-50 cursor-not-allowed'
      ]"
      aria-label="End Timer"
    >
      <Square class="h-5 w-5 text-red-500 fill-current" />
    </button>
  </div>
</template>
