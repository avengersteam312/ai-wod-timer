<script setup lang="ts">
import { ref, watch } from 'vue'
import { useWorkoutStore } from '@/stores/workoutStore'
import { useTimerStore } from '@/stores/timerStore'
import { storeToRefs } from 'pinia'
import WorkoutInput from '@/components/WorkoutInput.vue'
import ManualTimer from '@/components/ManualTimer.vue'
import { ArrowLeft, Volume2, VolumeX } from 'lucide-vue-next'
import { useAudio } from '@/composables/useAudio'
import { useTimer } from '@/composables/useTimer'
import { useTimerLayout } from '@/composables/useTimerLayout'
import ProfileMenu from '@/components/ProfileMenu.vue'
import {
  TimerBlock,
  CurrentMovementBlock,
  NextMovementBlock,
  ControlsBlock,
  WorkoutProgressBlock,
  WorkoutSummaryBlock,
  RoundCounterBlock
} from '@/components/timer/blocks'

type InputMode = 'ai' | 'manual'

const workoutStore = useWorkoutStore()
const timerStore = useTimerStore()
const { currentWorkout } = storeToRefs(workoutStore)
const { isCompleted, autoStart, skipPreparation } = storeToRefs(timerStore)
const { audioEnabled, toggleAudio } = useAudio()
const { startTimer } = useTimer()
const {
  showTimerBlock,
  showCurrentMovement,
  showNextMovement,
  showControls,
  showProgress,
  showCompletedCard,
  showWorkoutSummary,
  showRoundCounter
} = useTimerLayout()

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
const workoutTitle = () => {
  if (!currentWorkout.value) return ''
  return currentWorkout.value.workout_type.toUpperCase()
}
</script>

<template>
  <div class="min-h-screen bg-background">
    <!-- Workout Input Screen -->
    <div v-if="!currentWorkout" class="min-h-screen flex flex-col max-w-md mx-auto">
      <!-- Header -->
      <header class="flex items-center justify-between px-4 py-3">
        <!-- App Title -->
        <h1 class="text-sm font-semibold text-foreground font-athletic">
          AI Workout Timer
        </h1>
        <ProfileMenu />
      </header>

      <!-- Main Content -->
      <main class="flex-1 p-4 md:p-8">
        <!-- Mode Toggle - Centered above content -->
        <div class="flex justify-center mb-6">
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
              AI Build
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
        </div>

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

        <h1 class="text-base font-semibold text-foreground font-athletic">
          {{ workoutTitle() }}
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
        <TimerBlock v-if="showTimerBlock" />

        <!-- Round Counter -->
        <RoundCounterBlock v-if="showRoundCounter" />

        <!-- Timer Controls -->
        <ControlsBlock v-if="showControls" />

        <!-- Workout Summary -->
        <WorkoutSummaryBlock v-if="showWorkoutSummary" />

        <!-- Current Movement / Rest / Completed Card -->
        <CurrentMovementBlock
          v-if="showCurrentMovement"
          :show-completed-card="showCompletedCard"
        />

        <!-- Next Movement Preview -->
        <NextMovementBlock v-if="showNextMovement" />

        <!-- Start New Workout Button (when completed) -->
        <button
          v-if="isCompleted && showCompletedCard"
          @click="handleBack"
          class="w-full bg-timer-complete text-background font-semibold py-3 rounded-lg hover:bg-timer-complete/90 transition-colors"
        >
          Start New Workout
        </button>

        <!-- Movement List / Workout Progress -->
        <WorkoutProgressBlock v-if="showProgress" />
      </main>
    </div>
  </div>
</template>
