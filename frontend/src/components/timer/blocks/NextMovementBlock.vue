<script setup lang="ts">
import { computed } from 'vue'
import { useWorkoutStore } from '@/stores/workoutStore'
import { useTimerStore } from '@/stores/timerStore'
import { storeToRefs } from 'pinia'
import type { Movement } from '@/types/workout'

const workoutStore = useWorkoutStore()
const timerStore = useTimerStore()
const { currentWorkout } = storeToRefs(workoutStore)
const { isIntervalBased, isCompleted } = storeToRefs(timerStore)

// Next movement display
const nextMovement = computed(() => {
  if (!currentWorkout.value || isCompleted.value) return null
  if (isIntervalBased.value) {
    const movements = currentWorkout.value.movements
    const nextIdx = (timerStore.currentIntervalIndex + 1) % movements.length
    return movements[nextIdx] ?? null
  }
  return currentWorkout.value.movements[1] ?? null
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

const nextMovementDisplay = computed(() => {
  if (!nextMovement.value) return ''
  return formatMovementDisplay(nextMovement.value)
})

const hasNextMovement = computed(() => {
  return nextMovement.value && !isCompleted.value
})
</script>

<template>
  <div
    v-if="hasNextMovement"
    class="bg-surface-elevated rounded-lg px-3 py-2 flex items-center gap-2"
  >
    <span class="text-[10px] font-semibold tracking-wider text-muted-foreground">
      NEXT:
    </span>
    <span class="text-sm text-muted-foreground">
      {{ nextMovementDisplay }}
    </span>
  </div>
</template>
