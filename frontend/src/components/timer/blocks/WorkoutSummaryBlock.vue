<script setup lang="ts">
import { computed } from 'vue'
import { useWorkoutStore } from '@/stores/workoutStore'
import { storeToRefs } from 'pinia'
import type { Movement } from '@/types/workout'

const workoutStore = useWorkoutStore()
const { currentWorkout } = storeToRefs(workoutStore)

const movements = computed(() => currentWorkout.value?.movements ?? [])

const timeCap = computed(() => {
  const secs = currentWorkout.value?.time_cap
  if (!secs) return null
  const mins = Math.floor(secs / 60)
  const remainingSecs = secs % 60
  if (remainingSecs === 0) return `${mins} min`
  return `${mins}:${String(remainingSecs).padStart(2, '0')}`
})

const formatMovement = (movement: Movement) => {
  const parts: string[] = []

  if (movement.reps) {
    parts.push(`${movement.reps}`)
  } else if (movement.duration) {
    parts.push(`${movement.duration}s`)
  }

  parts.push(movement.name)

  if (movement.weight) {
    parts.push(`(${movement.weight})`)
  }

  return parts.join(' ')
}
</script>

<template>
  <div v-if="currentWorkout" class="bg-surface rounded-xl p-4">
    <p class="text-[10px] font-semibold tracking-wider text-muted-foreground mb-3 font-athletic">
      WORKOUT
    </p>

    <!-- Workout meta info -->
    <div v-if="timeCap" class="flex flex-wrap gap-2 mb-3">
      <span class="text-xs bg-surface-elevated px-2 py-1 rounded-md text-muted-foreground">
        Cap: {{ timeCap }}
      </span>
    </div>

    <!-- Movements list -->
    <ul class="space-y-2">
      <li
        v-for="(movement, idx) in movements"
        :key="idx"
        class="text-sm text-foreground"
      >
        {{ formatMovement(movement) }}
        <span v-if="movement.notes" class="text-xs text-muted-foreground ml-1">
          - {{ movement.notes }}
        </span>
      </li>
    </ul>
  </div>
</template>
