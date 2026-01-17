<script setup lang="ts">
import { useWorkoutStore } from '@/stores/workoutStore'
import { storeToRefs } from 'pinia'
import WorkoutInput from '@/components/WorkoutInput.vue'
import TimerDisplay from '@/components/timer/TimerDisplay.vue'
import TimerControls from '@/components/timer/TimerControls.vue'
import MovementList from '@/components/timer/MovementList.vue'
import Button from '@/components/ui/Button.vue'
import { ArrowLeft } from 'lucide-vue-next'

const workoutStore = useWorkoutStore()
const { currentWorkout } = storeToRefs(workoutStore)

const handleBack = () => {
  workoutStore.clearWorkout()
}
</script>

<template>
  <div class="min-h-screen bg-background p-4 md:p-8">
    <div class="max-w-6xl mx-auto">
      <div v-if="!currentWorkout">
        <WorkoutInput @workout-parsed="() => {}" />
      </div>

      <div v-else class="space-y-8">
        <div class="flex justify-between items-center">
          <Button @click="handleBack" variant="ghost">
            <ArrowLeft class="mr-2 h-4 w-4" />
            New Workout
          </Button>
        </div>

        <TimerDisplay />
        <TimerControls />
        <MovementList />
      </div>
    </div>
  </div>
</template>
