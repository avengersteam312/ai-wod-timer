<script setup lang="ts">
import { computed } from 'vue'
import { useWorkoutStore } from '@/stores/workoutStore'
import { useTimerStore } from '@/stores/timerStore'
import { storeToRefs } from 'pinia'
import type { Movement } from '@/types/workout'

interface Props {
  showCompletedCard?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  showCompletedCard: true
})

const workoutStore = useWorkoutStore()
const timerStore = useTimerStore()
const { currentWorkout } = storeToRefs(workoutStore)
const { currentInterval, isIntervalBased, isCompleted } = storeToRefs(timerStore)

// Current movement display
const currentMovement = computed(() => {
  if (!currentWorkout.value) return null
  if (isIntervalBased.value && currentInterval.value) {
    const movements = currentWorkout.value.movements
    const idx = timerStore.currentIntervalIndex % movements.length
    return movements[idx] ?? null
  }
  return currentWorkout.value.movements[0] ?? null
})

// Determine if we're in rest state
const isRestInterval = computed(() => {
  return currentInterval.value?.type === 'rest'
})

// Format movement display with reps/duration
const formatMovementDisplay = (movement: Movement) => {
  const repsOrDuration = movement.reps ?? movement.duration
  if (repsOrDuration != null) {
    const isDuration = movement.reps == null && movement.duration != null
    return `${repsOrDuration}${isDuration ? 's' : ''} ${movement.name}`
  }
  return movement.name
}

const currentMovementDisplay = computed(() => {
  if (!currentMovement.value) return ''
  return formatMovementDisplay(currentMovement.value)
})

// Total rounds for completed state
const totalRounds = computed(() => {
  if (!currentWorkout.value) return 0
  return (
    currentWorkout.value.rounds ||
    Math.ceil(timerStore.totalIntervals / currentWorkout.value.movements.length)
  )
})
</script>

<template>
  <!-- Current Movement Card -->
  <div v-if="currentMovement && !isRestInterval && !isCompleted" class="bg-surface rounded-xl p-4 text-center">
    <p class="text-[10px] font-semibold tracking-wider text-muted-foreground mb-1 font-athletic">
      CURRENT MOVEMENT
    </p>
    <h2 class="text-2xl font-bold text-foreground font-athletic">
      {{ currentMovementDisplay }}
    </h2>
    <p v-if="currentMovement.weight" class="text-sm text-muted-foreground mt-1">
      {{ currentMovement.weight }}
    </p>
  </div>

  <!-- Rest Interval Card -->
  <div v-else-if="isRestInterval && !isCompleted" class="bg-surface rounded-xl p-4 text-center">
    <p class="text-[10px] font-semibold tracking-wider text-muted-foreground mb-1 font-athletic">
      REST
    </p>
    <h2 class="text-2xl font-bold text-foreground font-athletic">
      Take a breath
    </h2>
    <p class="text-sm text-muted-foreground mt-1">
      Next round starts soon
    </p>
  </div>

  <!-- Completed Card (only shown when showCompletedCard is true) -->
  <div v-else-if="isCompleted && props.showCompletedCard" class="bg-surface rounded-xl p-4 text-center">
    <p class="text-[10px] font-semibold tracking-wider text-muted-foreground mb-1 font-athletic">
      TOTAL ROUNDS
    </p>
    <h2 class="text-2xl font-bold text-foreground font-athletic">
      {{ totalRounds }} Rounds
    </h2>
    <p class="text-sm text-muted-foreground mt-1">
      Workout complete!
    </p>
  </div>
</template>
