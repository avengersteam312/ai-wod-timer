<script setup lang="ts">
import { computed } from 'vue'
import { useTimerStore, TimerState } from '@/stores/timerStore'
import { storeToRefs } from 'pinia'
import { useTimer } from '@/composables/useTimer'
import { Play, Pause, RotateCcw, SkipForward, Check, Coffee } from 'lucide-vue-next'

const timerStore = useTimerStore()
const { state, isCompleted, currentInterval, skipPreparation, isWorkRestTimer, workRestPhase } = storeToRefs(timerStore)
const { startTimer, pauseTimer, resetTimer, triggerWorkRestRest } = useTimer()

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

// Show Done button for work_rest timer during work phase while running
const showDoneButton = computed(() =>
  isWorkRestTimer.value && workRestPhase.value === 'work' && state.value === TimerState.RUNNING
)

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
      class="w-12 h-12 rounded-full bg-surface-elevated hover:bg-surface-elevated/80 flex items-center justify-center transition-colors"
      aria-label="Reset"
    >
      <RotateCcw class="h-5 w-5 text-muted-foreground" />
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
      class="w-12 h-12 rounded-full bg-timer-rest hover:bg-timer-rest/90 flex items-center justify-center transition-colors"
      aria-label="Done - Start Rest"
    >
      <Coffee class="h-5 w-5 text-background" />
    </button>

    <!-- Skip Button (Secondary - 48px) -->
    <button
      v-else
      class="w-12 h-12 rounded-full bg-surface-elevated hover:bg-surface-elevated/80 flex items-center justify-center transition-colors"
      aria-label="Skip"
    >
      <SkipForward class="h-5 w-5 text-muted-foreground" />
    </button>
  </div>
</template>
