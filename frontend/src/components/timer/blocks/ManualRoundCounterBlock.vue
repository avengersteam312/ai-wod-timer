<script setup lang="ts">
import { computed } from 'vue'
import { useWorkoutStore } from '@/stores/workoutStore'
import { useTimerStore } from '@/stores/timerStore'
import { storeToRefs } from 'pinia'

const workoutStore = useWorkoutStore()
const timerStore = useTimerStore()
const { currentWorkout } = storeToRefs(workoutStore)
const { manualRounds, isWorkRestTimer } = storeToRefs(timerStore)

// Check if RoundCounterBlock would be shown (to avoid duplicate counters)
const hasRoundCounterBlock = computed(() => {
  if (isWorkRestTimer.value) return true
  const intervals = currentWorkout.value?.timer_config?.intervals
  if (!intervals) return false
  // RoundCounterBlock shows for 2+ intervals or any repeat interval
  const hasRepeat = intervals.some(i => i.repeat)
  return hasRepeat || intervals.length >= 2
})

// Check if this timer should show manual round counter
// Show for timers without predefined rounds (when RoundCounterBlock doesn't show)
const shouldShow = computed(() => {
  const type = currentWorkout.value?.workout_type
  if (!type) return false

  // Don't show if RoundCounterBlock is already showing
  if (hasRoundCounterBlock.value) return false

  // Don't show for rest timer (no rounds concept)
  if (type === 'rest') return false

  // Show for amrap, for_time, stopwatch, and other workout types without predefined rounds
  return true
})

// Format duration to MM:SS
const formatDuration = (seconds: number) => {
  const mins = Math.floor(seconds / 60)
  const secs = seconds % 60
  return `${mins}:${String(secs).padStart(2, '0')}`
}

// Current round count
const roundCount = computed(() => manualRounds.value.length)

// Last round duration
const lastRoundDuration = computed(() => {
  const rounds = manualRounds.value
  if (rounds.length === 0) return null
  return rounds[rounds.length - 1]?.duration ?? null
})
</script>

<template>
  <div v-if="shouldShow" class="bg-surface rounded-xl p-4">
    <div class="flex items-center justify-between">
      <!-- Round count display -->
      <div class="text-xl font-bold font-athletic text-foreground">
        ROUNDS: {{ roundCount }}
      </div>

      <!-- Last round info -->
      <div v-if="lastRoundDuration !== null" class="text-sm text-muted-foreground">
        Last: {{ formatDuration(lastRoundDuration) }}
      </div>
    </div>
  </div>
</template>
