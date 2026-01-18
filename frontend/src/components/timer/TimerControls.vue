<script setup lang="ts">
import { computed } from 'vue'
import { useTimerStore, TimerState } from '@/stores/timerStore'
import { storeToRefs } from 'pinia'
import { useTimer } from '@/composables/useTimer'
import { Play, Pause, RotateCcw, SkipForward, Check } from 'lucide-vue-next'

const timerStore = useTimerStore()
const { state, isCompleted, currentInterval } = storeToRefs(timerStore)
const { startTimer, pauseTimer, resetTimer } = useTimer()

const handleStartPause = () => {
  if (state.value === TimerState.RUNNING || state.value === TimerState.PREPARING) {
    pauseTimer()
  } else {
    startTimer()
  }
}

const isActive = computed(() =>
  state.value === TimerState.RUNNING || state.value === TimerState.PREPARING
)

// Determine primary button color based on state
const primaryButtonClass = computed(() => {
  if (isCompleted.value) return 'bg-timer-complete hover:bg-timer-complete/90'
  if (currentInterval.value?.type === 'rest') return 'bg-timer-rest hover:bg-timer-rest/90'
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
    <button
      @click="handleStartPause"
      :class="[
        'w-[72px] h-[72px] rounded-full flex items-center justify-center transition-colors',
        primaryButtonClass
      ]"
      aria-label="Play/Pause"
    >
      <Check v-if="isCompleted" class="h-8 w-8 text-background" />
      <Pause v-else-if="isActive" class="h-8 w-8 text-background" />
      <Play v-else class="h-8 w-8 text-background ml-1" />
    </button>

    <!-- Skip Button (Secondary - 48px) -->
    <button
      class="w-12 h-12 rounded-full bg-surface-elevated hover:bg-surface-elevated/80 flex items-center justify-center transition-colors"
      aria-label="Skip"
    >
      <SkipForward class="h-5 w-5 text-muted-foreground" />
    </button>
  </div>
</template>
