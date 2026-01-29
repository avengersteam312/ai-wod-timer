<script setup lang="ts">
import { ref, watch, computed } from 'vue'
import { useWorkoutStore } from '@/stores/workoutStore'
import { useTimerStore } from '@/stores/timerStore'
import { useSupabaseAuthStore } from '@/stores/supabaseAuthStore'
import { storeToRefs } from 'pinia'
import WorkoutInput from '@/components/WorkoutInput.vue'
import ManualTimer from '@/components/ManualTimer.vue'
import { ArrowLeft, Volume2, VolumeX, Save, Check } from 'lucide-vue-next'
import { useAudio } from '@/composables/useAudio'
import { useTimer } from '@/composables/useTimer'
import { useTimerLayout } from '@/composables/useTimerLayout'
import ProfileMenu from '@/components/ProfileMenu.vue'
import BottomNav from '@/components/BottomNav.vue'
import BottomSheet from '@/components/ui/BottomSheet.vue'
import { saveWorkout } from '@/services/workoutService'
import {
  TimerBlock,
  CurrentMovementBlock,
  NextMovementBlock,
  ControlsBlock,
  WorkoutProgressBlock,
  WorkoutSummaryBlock,
  RoundCounterBlock,
  ManualRoundCounterBlock
} from '@/components/timer/blocks'

type InputMode = 'ai' | 'manual'

const workoutStore = useWorkoutStore()
const timerStore = useTimerStore()
const authStore = useSupabaseAuthStore()
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

// Save workout state
const showSaveModal = ref(false)
const workoutName = ref('')
const isSaving = ref(false)
const isSaved = ref(false)
const savedWorkoutId = ref<string | null>(null)
const saveError = ref<string | null>(null)
const saveSuccess = ref(false)

// Show save button only when authenticated and workout exists
const canSave = computed(() => authStore.isAuthenticated && currentWorkout.value && !isSaved.value)

// Generate default workout name from workout type
const defaultWorkoutName = computed(() => {
  if (!currentWorkout.value) return ''
  const type = currentWorkout.value.workout_type.toUpperCase()
  const date = new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
  return `${type} - ${date}`
})

const openSaveModal = () => {
  workoutName.value = defaultWorkoutName.value
  saveError.value = null
  showSaveModal.value = true
}

const closeSaveModal = () => {
  showSaveModal.value = false
  saveError.value = null
}

const handleSaveWorkout = async () => {
  if (!currentWorkout.value || !workoutName.value.trim()) return

  isSaving.value = true
  saveError.value = null

  try {
    const saved = await saveWorkout(currentWorkout.value, workoutName.value.trim())
    savedWorkoutId.value = saved.id
    isSaved.value = true
    saveSuccess.value = true
    showSaveModal.value = false

    // Clear success message after 3 seconds
    setTimeout(() => {
      saveSuccess.value = false
    }, 3000)
  } catch (err) {
    saveError.value = err instanceof Error ? err.message : 'Failed to save workout'
  } finally {
    isSaving.value = false
  }
}

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
  // Reset saved state for new workout
  isSaved.value = false
  savedWorkoutId.value = null
  saveSuccess.value = false
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
      <main class="flex-1 p-4 md:p-8 pb-20">
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

        <div class="flex items-center gap-1">
          <!-- Save Workout Button -->
          <button
            v-if="canSave"
            @click="openSaveModal"
            class="p-2 text-foreground hover:text-muted-foreground transition-colors"
            aria-label="Save workout"
          >
            <Save class="h-6 w-6" />
          </button>
          <!-- Saved Indicator -->
          <div
            v-else-if="isSaved"
            class="p-2 text-timer-complete"
            aria-label="Workout saved"
          >
            <Check class="h-6 w-6" />
          </div>
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

      <!-- Save Success Toast -->
      <Transition
        enter-active-class="transition ease-out duration-200"
        enter-from-class="opacity-0 -translate-y-2"
        enter-to-class="opacity-100 translate-y-0"
        leave-active-class="transition ease-in duration-150"
        leave-from-class="opacity-100 translate-y-0"
        leave-to-class="opacity-0 -translate-y-2"
      >
        <div
          v-if="saveSuccess"
          class="mx-4 mb-2 px-4 py-2 bg-timer-complete/20 border border-timer-complete/30 text-timer-complete rounded-lg text-sm text-center"
        >
          Workout saved successfully!
        </div>
      </Transition>

      <!-- Main Content -->
      <main class="flex-1 flex flex-col px-4 pb-20 space-y-4">
        <!-- Timer Display with Ring -->
        <TimerBlock v-if="showTimerBlock" />

        <!-- Round Counter -->
        <RoundCounterBlock v-if="showRoundCounter" />

        <!-- Manual Round Counter (for AMRAP, for_time, stopwatch) -->
        <ManualRoundCounterBlock />

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

    <!-- Save Workout Modal -->
    <BottomSheet
      :open="showSaveModal"
      title="Save Workout"
      @update:open="(val) => !val && closeSaveModal()"
    >
      <div class="space-y-4">
        <div>
          <label for="workout-name" class="block text-sm font-medium text-foreground mb-2">
            Workout Name
          </label>
          <input
            id="workout-name"
            v-model="workoutName"
            type="text"
            placeholder="Enter workout name"
            class="w-full px-3 py-2 bg-background border border-border rounded-lg text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent"
            @keyup.enter="handleSaveWorkout"
          />
        </div>

        <!-- Error message -->
        <div
          v-if="saveError"
          class="px-3 py-2 bg-destructive/20 border border-destructive/30 text-destructive rounded-lg text-sm"
        >
          {{ saveError }}
        </div>
      </div>

      <template #actions>
        <div class="flex gap-3">
          <button
            @click="closeSaveModal"
            class="flex-1 px-4 py-2 border border-border rounded-lg text-foreground hover:bg-surface transition-colors"
            :disabled="isSaving"
          >
            Cancel
          </button>
          <button
            @click="handleSaveWorkout"
            class="flex-1 px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            :disabled="isSaving || !workoutName.trim()"
          >
            {{ isSaving ? 'Saving...' : 'Save' }}
          </button>
        </div>
      </template>
    </BottomSheet>

    <!-- Bottom Navigation -->
    <BottomNav />
  </div>
</template>
