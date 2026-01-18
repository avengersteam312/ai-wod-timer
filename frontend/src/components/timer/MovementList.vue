<script setup lang="ts">
import { computed } from 'vue'
import { useWorkoutStore } from '@/stores/workoutStore'
import { useTimerStore } from '@/stores/timerStore'
import { storeToRefs } from 'pinia'

const workoutStore = useWorkoutStore()
const timerStore = useTimerStore()
const { currentWorkout } = storeToRefs(workoutStore)
const { currentIntervalIndex, isCompleted, totalIntervals, isIntervalBased } = storeToRefs(timerStore)

// For interval-based workouts, create a list of rounds with their status
const roundsList = computed(() => {
  if (!currentWorkout.value || !isIntervalBased.value) return []

  const rounds = []
  const movements = currentWorkout.value.movements
  const movementCount = movements.length

  // Calculate rounds based on intervals
  const roundCount = Math.ceil(totalIntervals.value / movementCount)

  for (let i = 0; i < Math.min(roundCount, 4); i++) { // Show max 4 rounds
    const movementIndex = i % movementCount
    const movement = movements[movementIndex]
    const intervalIndex = i

    let status: 'completed' | 'current' | 'pending' = 'pending'
    if (intervalIndex < currentIntervalIndex.value) {
      status = 'completed'
    } else if (intervalIndex === currentIntervalIndex.value) {
      status = 'current'
    }

    if (isCompleted.value) {
      status = 'completed'
    }

    rounds.push({
      roundNumber: i + 1,
      movement: `${movement.reps || movement.duration}${movement.duration ? 's' : ''} ${movement.name}`,
      status
    })
  }

  return rounds
})

// For non-interval workouts, show the movement list
const movementsList = computed(() => {
  if (!currentWorkout.value) return []
  return currentWorkout.value.movements.map((movement, index) => ({
    reps: movement.reps || movement.duration,
    unit: movement.duration ? 's' : '',
    name: movement.name,
    weight: movement.weight
  }))
})
</script>

<template>
  <div v-if="currentWorkout" class="bg-surface rounded-xl p-4">
    <h4 class="text-xs font-semibold text-muted-foreground mb-3">Workout Progress</h4>

    <!-- Interval-based workout: show rounds with status -->
    <div v-if="isIntervalBased && roundsList.length" class="space-y-2">
      <div
        v-for="round in roundsList"
        :key="round.roundNumber"
        class="flex items-center gap-3"
      >
        <!-- Status Indicator -->
        <div
          :class="[
            'w-2 h-2 rounded-full flex-shrink-0',
            round.status === 'completed' ? 'bg-timer-complete' :
            round.status === 'current' ? 'bg-timer-work' :
            'bg-surface-elevated'
          ]"
        />

        <!-- Round Number -->
        <span
          :class="[
            'text-xs font-semibold w-6',
            round.status === 'current' ? 'text-timer-work' : 'text-muted-foreground'
          ]"
        >
          R{{ round.roundNumber }}
        </span>

        <!-- Movement -->
        <span
          :class="[
            'text-sm',
            round.status === 'completed' ? 'text-muted-foreground' :
            round.status === 'current' ? 'text-foreground font-medium' :
            'text-muted-foreground'
          ]"
        >
          {{ round.movement }}
        </span>
      </div>
    </div>

    <!-- Non-interval workout: show movement list -->
    <div v-else class="space-y-2">
      <div
        v-for="(movement, index) in movementsList"
        :key="index"
        class="flex items-baseline gap-2"
      >
        <span class="font-mono text-sm text-timer-work">
          {{ movement.reps }}{{ movement.unit }}
        </span>
        <span class="text-sm text-foreground">{{ movement.name }}</span>
        <span v-if="movement.weight" class="text-xs text-muted-foreground">
          ({{ movement.weight }})
        </span>
      </div>
    </div>
  </div>
</template>
