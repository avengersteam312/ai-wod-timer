<script setup lang="ts">
import { computed } from 'vue'
import { useWorkoutStore } from '@/stores/workoutStore'
import { storeToRefs } from 'pinia'
import Card from '@/components/ui/Card.vue'

const workoutStore = useWorkoutStore()
const { currentWorkout } = storeToRefs(workoutStore)

const workoutTypeLabel = computed(() => {
  if (!currentWorkout.value) return ''

  const type = currentWorkout.value.workout_type.toUpperCase()
  const duration = currentWorkout.value.duration
  const rounds = currentWorkout.value.rounds

  if (duration) {
    return `${type} ${Math.floor(duration / 60)} minutes`
  }
  if (rounds) {
    return `${rounds} Rounds ${type}`
  }
  return type
})
</script>

<template>
  <Card v-if="currentWorkout" class="p-6">
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <h3 class="text-xl font-semibold">{{ workoutTypeLabel }}</h3>
        <span v-if="currentWorkout.rounds" class="text-sm text-muted-foreground">
          {{ currentWorkout.rounds }} rounds
        </span>
      </div>

      <div class="space-y-2">
        <div
          v-for="(movement, index) in currentWorkout.movements"
          :key="index"
          class="flex items-baseline gap-2 text-lg"
        >
          <span class="font-mono text-primary">
            {{ movement.reps || movement.duration }}{{ movement.duration ? 's' : '' }}
          </span>
          <span class="font-medium">{{ movement.name }}</span>
          <span v-if="movement.weight" class="text-sm text-muted-foreground">
            ({{ movement.weight }})
          </span>
        </div>
      </div>

      <div v-if="currentWorkout.ai_interpretation" class="pt-4 border-t">
        <p class="text-sm text-muted-foreground italic">
          {{ currentWorkout.ai_interpretation }}
        </p>
      </div>
    </div>
  </Card>
</template>
