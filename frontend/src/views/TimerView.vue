<script setup lang="ts">
import { ref, watch, computed } from 'vue'
import { useWorkoutStore } from '@/stores/workoutStore'
import { useTimerStore, TimerState } from '@/stores/timerStore'
import { useSupabaseAuthStore } from '@/stores/supabaseAuthStore'
import { storeToRefs } from 'pinia'
import WorkoutInput from '@/components/WorkoutInput.vue'
import { ArrowLeft, Volume2, VolumeX } from 'lucide-vue-next'
import { useAudio } from '@/composables/useAudio'
import { useTimer } from '@/composables/useTimer'
import { useTimerLayout } from '@/composables/useTimerLayout'
import { useSessionTracking } from '@/composables/useSessionTracking'
import ProfileMenu from '@/components/ProfileMenu.vue'
import BottomNav from '@/components/BottomNav.vue'
import BottomSheet from '@/components/ui/BottomSheet.vue'
import OfflineIndicator from '@/components/OfflineIndicator.vue'
import OfflineSaveToast from '@/components/OfflineSaveToast.vue'
import { saveWorkout } from '@/services/workoutService'
import { proposeWorkoutName, MAX_WORKOUT_NAME_LENGTH } from '@/utils/workoutName'
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

const workoutStore = useWorkoutStore()
const timerStore = useTimerStore()
const authStore = useSupabaseAuthStore()
const { currentWorkout } = storeToRefs(workoutStore)
const { isCompleted, autoStart, skipPreparation, state: timerState } = storeToRefs(timerStore)
const { voiceEnabled, toggleVoice } = useAudio()
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

// Session tracking - automatically tracks workout sessions in database
useSessionTracking()

// Save workout state
const showSaveModal = ref(false)
const workoutName = ref('')
const isSaving = ref(false)
const isSaved = ref(false)
const savedWorkoutId = ref<string | null>(null)
const saveError = ref<string | null>(null)
const saveSuccess = ref(false)
const savedOffline = ref(false)

// When save modal was opened from Done/Start New Workout or Save for later, we exit after save or Don't save
const saveThenExit = ref(false)

// Pre-plan: show "Save for later" when timer hasn't started yet (IDLE)
// Only show for newly created workouts (AI timer), not when loaded from Saved Timers
const showSaveForLater = computed(() =>
  authStore.isAuthenticated &&
  currentWorkout.value &&
  !workoutStore.loadedFromWorkoutId &&
  !isSaved.value &&
  timerState.value === TimerState.IDLE
)

const openEndSessionSavePrompt = () => {
  // Already saved (e.g. loaded from My Workouts) → exit without prompting
  if (workoutStore.loadedFromWorkoutId) {
    handleBack()
    return
  }
  if (authStore.isAuthenticated && currentWorkout.value && !isSaved.value) {
    saveThenExit.value = true
    workoutName.value = proposeWorkoutName(currentWorkout.value)
    saveError.value = null
    showSaveModal.value = true
  } else {
    handleBack()
  }
}

const closeSaveModal = () => {
  showSaveModal.value = false
  saveError.value = null
  saveThenExit.value = false
}

const handleDontSave = () => {
  closeSaveModal()
  handleBack()
}

const handleSaveWorkout = async () => {
  if (!currentWorkout.value || !workoutName.value.trim()) return

  isSaving.value = true
  saveError.value = null
  const nameToSave = workoutName.value.trim().slice(0, MAX_WORKOUT_NAME_LENGTH)

  try {
    const result = await saveWorkout(currentWorkout.value, nameToSave)
    savedWorkoutId.value = result.workout.id
    isSaved.value = true
    savedOffline.value = result.savedOffline
    saveSuccess.value = true
    showSaveModal.value = false

    if (saveThenExit.value) {
      saveThenExit.value = false
      handleBack()
      return
    }

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


const handleBack = () => {
  workoutStore.clearWorkout()
  timerStore.reset()
  // Reset saved state for new workout
  isSaved.value = false
  savedWorkoutId.value = null
  saveSuccess.value = false
  savedOffline.value = false
}
</script>

<template>
  <div class="min-h-screen bg-background">
    <!-- Workout Input Screen -->
    <div v-if="!currentWorkout" class="min-h-screen flex flex-col max-w-md mx-auto">
      <!-- Header -->
      <header class="flex items-center justify-between px-4 py-3 safe-area-pt">
        <!-- App Title -->
        <h1 class="text-sm font-semibold text-foreground font-athletic">
          AI Workout Timer
        </h1>
        <div class="flex items-center gap-2">
          <OfflineIndicator />
          <ProfileMenu />
        </div>
      </header>

      <!-- Main Content -->
      <main class="flex-1 p-4 md:p-8 pb-20">
        <WorkoutInput @workout-parsed="() => {}" />
      </main>
    </div>

    <!-- Timer Screen (Mobile-optimized layout) -->
    <div v-else class="min-h-screen flex flex-col max-w-md mx-auto">
      <!-- Header -->
      <header class="flex items-center justify-between px-4 py-3 safe-area-pt">
        <button
          @click="handleBack"
          class="p-2 -ml-2 text-foreground hover:text-muted-foreground transition-colors"
          aria-label="Back"
        >
          <ArrowLeft class="h-6 w-6" />
        </button>

        <div class="flex items-center gap-2">
          <OfflineIndicator />
        </div>

        <div class="flex items-center gap-1">
          <button
            @click="toggleVoice"
            class="p-2 text-foreground hover:text-muted-foreground transition-colors"
            aria-label="Toggle voice"
          >
            <Volume2 v-if="voiceEnabled" class="h-6 w-6" />
            <VolumeX v-else class="h-6 w-6" />
          </button>
          <ProfileMenu />
        </div>
      </header>

      <!-- Offline Save Toast (shows when saved locally) -->
      <OfflineSaveToast :show="saveSuccess && savedOffline" />

      <!-- Online Save Success Toast -->
      <Transition
        enter-active-class="transition ease-out duration-200"
        enter-from-class="opacity-0 -translate-y-2"
        enter-to-class="opacity-100 translate-y-0"
        leave-active-class="transition ease-in duration-150"
        leave-from-class="opacity-100 translate-y-0"
        leave-to-class="opacity-0 -translate-y-2"
      >
        <div
          v-if="saveSuccess && !savedOffline"
          class="mx-4 mb-2 px-4 py-2 bg-timer-complete/20 border border-timer-complete/30 text-timer-complete rounded-lg text-sm text-center"
        >
          Workout saved successfully!
        </div>
      </Transition>

      <!-- Main Content -->
      <main class="flex-1 flex flex-col px-4 pb-20 space-y-4">
        <!-- Save for later (pre-plan): before starting the timer -->
        <div
          v-if="showSaveForLater"
          class="flex justify-center"
        >
          <button
            type="button"
            @click="openEndSessionSavePrompt"
            class="text-sm text-muted-foreground hover:text-foreground transition-colors"
          >
            Save for later
          </button>
        </div>

        <!-- Timer Display with Ring -->
        <TimerBlock v-if="showTimerBlock" />

        <!-- Timer Controls -->
        <ControlsBlock v-if="showControls" @done="openEndSessionSavePrompt" />

        <!-- Round Counter -->
        <RoundCounterBlock v-if="showRoundCounter" />

        <!-- Manual Round Counter (for AMRAP, for_time, stopwatch) -->
        <ManualRoundCounterBlock />

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
          @click="openEndSessionSavePrompt"
          class="w-full bg-timer-complete text-background font-semibold py-3 rounded-lg hover:bg-timer-complete/90 transition-colors"
        >
          Start New Workout
        </button>

        <!-- Movement List / Workout Progress -->
        <WorkoutProgressBlock v-if="showProgress" />
      </main>
    </div>

    <!-- Save Workout Modal (shown when ending session via Done or Start New Workout) -->
    <BottomSheet
      :open="showSaveModal"
      title="Save this workout?"
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
            maxlength="18"
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
            @click="handleDontSave"
            class="flex-1 px-4 py-2 border border-border rounded-lg text-foreground hover:bg-surface transition-colors"
            :disabled="isSaving"
          >
            Don't save
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
