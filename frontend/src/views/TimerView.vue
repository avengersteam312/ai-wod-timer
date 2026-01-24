<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useWorkoutStore } from '@/stores/workoutStore'
import { useTimerStore } from '@/stores/timerStore'
import { storeToRefs } from 'pinia'
import WorkoutInput from '@/components/WorkoutInput.vue'
import ManualTimer from '@/components/ManualTimer.vue'
import TimerDisplay from '@/components/timer/TimerDisplay.vue'
import TimerControls from '@/components/timer/TimerControls.vue'
import MovementList from '@/components/timer/MovementList.vue'
import { ArrowLeft, Volume2, VolumeX } from 'lucide-vue-next'
import { useAudio } from '@/composables/useAudio'
import { useTimer } from '@/composables/useTimer'
import ProfileMenu from '@/components/ProfileMenu.vue'

type InputMode = 'ai' | 'manual'

const workoutStore = useWorkoutStore()
const timerStore = useTimerStore()
const { currentWorkout } = storeToRefs(workoutStore)
const { currentInterval, isIntervalBased, isCompleted, autoStart, skipPreparation } = storeToRefs(timerStore)
const { audioEnabled, toggleAudio } = useAudio()
const { startTimer } = useTimer()

// Input mode toggle state
const inputMode = ref<InputMode>('ai')

// Watch for auto-start flag when workout is loaded
watch(currentWorkout, (workout) => {
  if (workout && autoStart.value) {
    // Auto-start the timer (with or without preparation based on flag)
    startTimer(skipPreparation.value)
    timerStore.clearAutoStart()
  }
}, { immediate: true })

// Watch for rest timer completion - redirect back to manual timer list immediately
watch(isCompleted, (completed) => {
  if (completed && currentWorkout.value?.workout_type === 'custom' && currentWorkout.value?.raw_text?.includes('Rest')) {
    workoutStore.clearWorkout()
    timerStore.reset()
    inputMode.value = 'manual'
  }
})

const handleBack = () => {
  workoutStore.clearWorkout()
}

// Workout title for header
const workoutTitle = computed(() => {
  if (!currentWorkout.value) return ''
  return currentWorkout.value.workout_type.toUpperCase()
})

// Current movement display
const currentMovement = computed(() => {
  if (!currentWorkout.value) return null
  if (isIntervalBased.value && currentInterval.value) {
    // Find the movement for the current interval
    const movements = currentWorkout.value.movements
    const idx = (timerStore.currentIntervalIndex) % movements.length
    return movements[idx]
  }
  // For non-interval workouts, show first movement
  return currentWorkout.value.movements[0]
})

// Next movement display
const nextMovement = computed(() => {
  if (!currentWorkout.value || isCompleted.value) return null
  if (isIntervalBased.value) {
    const movements = currentWorkout.value.movements
    const nextIdx = (timerStore.currentIntervalIndex + 1) % movements.length
    return movements[nextIdx]
  }
  return currentWorkout.value.movements[1] || null
})

// Determine if we're in rest state
const isRestInterval = computed(() => {
  return currentInterval.value?.type === 'rest'
})
</script>

<template>
  <div class="min-h-screen bg-background">
    <!-- Workout Input Screen -->
    <div v-if="!currentWorkout" class="min-h-screen flex flex-col max-w-md mx-auto">
      <!-- Header -->
      <header class="flex items-center justify-between px-4 py-3">
        <!-- Mode Toggle -->
        <div class="flex bg-surface rounded-full p-1">
          <button
            @click="inputMode = 'ai'"
            :class="[
              'px-3 py-1.5 rounded-full text-xs font-medium transition-colors',
              inputMode === 'ai'
                ? 'bg-primary text-primary-foreground'
                : 'text-muted-foreground hover:text-foreground'
            ]"
          >
            AI Parse
          </button>
          <button
            @click="inputMode = 'manual'"
            :class="[
              'px-3 py-1.5 rounded-full text-xs font-medium transition-colors',
              inputMode === 'manual'
                ? 'bg-primary text-primary-foreground'
                : 'text-muted-foreground hover:text-foreground'
            ]"
          >
            Manual
          </button>
        </div>
        <ProfileMenu />
      </header>

      <!-- Main Content -->
      <main class="flex-1 p-4 md:p-8">
        <WorkoutInput
          v-if="inputMode === 'ai'"
          @workout-parsed="() => {}"
          @switch-to-manual="inputMode = 'manual'"
        />
        <ManualTimer
          v-else
          @switch-to-a-i="inputMode = 'ai'"
        />
      </main>
    </div>

    <!-- Timer Screen (Mobile-optimized layout) -->
    <div v-else class="min-h-screen flex flex-col max-w-md mx-auto">
      <!-- Header -->
      <header class="flex items-center justify-between px-4 py-3">
        <button
          @click="handleBack"
          class="p-2 -ml-2 text-foreground hover:text-muted-foreground transition-colors"
          aria-label="Back"
        >
          <ArrowLeft class="h-6 w-6" />
        </button>

        <h1 class="text-base font-semibold text-foreground">
          {{ workoutTitle }}
        </h1>

        <div class="flex items-center gap-2">
          <button
            @click="toggleAudio"
            class="p-2 text-foreground hover:text-muted-foreground transition-colors"
            aria-label="Toggle audio"
          >
            <Volume2 v-if="audioEnabled" class="h-6 w-6" />
            <VolumeX v-else class="h-6 w-6" />
          </button>
          <ProfileMenu />
        </div>
      </header>

      <!-- Main Content -->
      <main class="flex-1 flex flex-col px-4 pb-4 space-y-4">
        <!-- Timer Display with Ring -->
        <div class="flex justify-center py-4">
          <TimerDisplay />
        </div>

        <!-- Current Movement Card -->
        <div v-if="currentMovement && !isRestInterval" class="bg-surface rounded-xl p-4 text-center">
          <p class="text-[10px] font-semibold tracking-wider text-muted-foreground mb-1">
            CURRENT MOVEMENT
          </p>
          <h2 class="text-2xl font-bold text-foreground">
            {{ currentMovement.reps || currentMovement.duration }}{{ currentMovement.duration ? 's' : '' }} {{ currentMovement.name }}
          </h2>
          <p v-if="currentMovement.weight" class="text-sm text-muted-foreground mt-1">
            {{ currentMovement.weight }}
          </p>
        </div>

        <!-- Rest Interval Card -->
        <div v-else-if="isRestInterval" class="bg-surface rounded-xl p-4 text-center">
          <p class="text-[10px] font-semibold tracking-wider text-muted-foreground mb-1">
            REST
          </p>
          <h2 class="text-2xl font-bold text-foreground">
            Take a breath
          </h2>
          <p class="text-sm text-muted-foreground mt-1">
            Next round starts soon
          </p>
        </div>

        <!-- Completed Card -->
        <div v-else-if="isCompleted" class="bg-surface rounded-xl p-4 text-center">
          <p class="text-[10px] font-semibold tracking-wider text-muted-foreground mb-1">
            TOTAL ROUNDS
          </p>
          <h2 class="text-2xl font-bold text-foreground">
            {{ currentWorkout.rounds || Math.ceil(timerStore.totalIntervals / currentWorkout.movements.length) }} Rounds
          </h2>
          <p class="text-sm text-muted-foreground mt-1">
            Workout complete!
          </p>
        </div>

        <!-- Next Movement Preview -->
        <div v-if="nextMovement && !isCompleted" class="bg-surface-elevated rounded-lg px-3 py-2 flex items-center gap-2">
          <span class="text-[10px] font-semibold tracking-wider text-muted-foreground">
            NEXT:
          </span>
          <span class="text-sm text-muted-foreground">
            {{ nextMovement.reps || nextMovement.duration }}{{ nextMovement.duration ? 's' : '' }} {{ nextMovement.name }}
          </span>
        </div>

        <!-- Start New Workout Button (when completed) -->
        <button
          v-if="isCompleted"
          @click="handleBack"
          class="w-full bg-timer-complete text-background font-semibold py-3 rounded-lg hover:bg-timer-complete/90 transition-colors"
        >
          Start New Workout
        </button>

        <!-- Timer Controls -->
        <div class="py-2">
          <TimerControls />
        </div>

        <!-- Movement List -->
        <MovementList />
      </main>
    </div>
  </div>
</template>
