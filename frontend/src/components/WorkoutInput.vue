<script setup lang="ts">
import { ref, watch, computed, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useWorkoutStore } from '@/stores/workoutStore'
import { useTimerStore } from '@/stores/timerStore'
import { useSupabaseAuthStore } from '@/stores/supabaseAuthStore'
import Button from '@/components/ui/Button.vue'
import Card from '@/components/ui/Card.vue'
import Textarea from '@/components/ui/Textarea.vue'
import BottomSheet from '@/components/ui/BottomSheet.vue'
import { Loader2, Sparkles } from 'lucide-vue-next'
import { getWorkouts, deleteWorkout, type Workout } from '@/services/workoutService'

const router = useRouter()
const workoutStore = useWorkoutStore()
const timerStore = useTimerStore()
const authStore = useSupabaseAuthStore()

const workoutText = ref('')

/** Max saved workouts to show on this screen; rest are in My Workouts / History */
const MAX_SAVED_WORKOUTS_DISPLAY = 12

/** Max characters for workout name in list (avoids cut-off on all screen sizes) */
const MAX_NAME_CHARS = 18
function displayName(name: string): string {
  if (name.length <= MAX_NAME_CHARS) return name
  return name.slice(0, MAX_NAME_CHARS - 3) + '...'
}

// My Workouts (saved by user)
const myWorkouts = ref<Workout[]>([])
const myWorkoutsLoading = ref(false)
const myWorkoutsError = ref<string | null>(null)

const loadMyWorkouts = async () => {
  if (!authStore.isAuthenticated) {
    myWorkouts.value = []
    return
  }
  myWorkoutsLoading.value = true
  myWorkoutsError.value = null
  try {
    myWorkouts.value = await getWorkouts()
  } catch (err) {
    myWorkoutsError.value = err instanceof Error ? err.message : 'Failed to load workouts'
    myWorkouts.value = []
  } finally {
    myWorkoutsLoading.value = false
  }
}

watch(() => authStore.isAuthenticated, (isAuth) => {
  if (isAuth) loadMyWorkouts()
  else myWorkouts.value = []
}, { immediate: true })

/** Saved workouts to show here (capped); order unchanged from API (e.g. updated_at desc) */
const displayedSavedWorkouts = computed(() =>
  myWorkouts.value.slice(0, MAX_SAVED_WORKOUTS_DISPLAY)
)

const savedWorkoutsOverflowCount = computed(() =>
  Math.max(0, myWorkouts.value.length - MAX_SAVED_WORKOUTS_DISPLAY)
)

const loadSavedWorkout = (workout: Workout) => {
  workoutStore.setManualWorkout(workout.parsed_config, workout.id)
  timerStore.setConfig(workout.parsed_config.timer_config, { autoStart: false })
}

// ---- Long-press to delete ----
const LONG_PRESS_MS = 500
let longPressTimer: ReturnType<typeof setTimeout> | null = null
/** When set, the next click should not open the workout (long press was used) */
const longPressHandled = ref(false)

type DeleteTarget = { type: 'saved'; workout: Workout }

const deleteTarget = ref<DeleteTarget | null>(null)
const showDeleteModal = ref(false)
const isDeleting = ref(false)
const deleteError = ref<string | null>(null)

function startLongPress(target: DeleteTarget) {
  longPressTimer = setTimeout(() => {
    longPressTimer = null
    longPressHandled.value = true
    deleteTarget.value = target
    deleteError.value = null
    showDeleteModal.value = true
  }, LONG_PRESS_MS)
}

function cancelLongPress() {
  if (longPressTimer) {
    clearTimeout(longPressTimer)
    longPressTimer = null
  }
}

function onSavedTouchStart(workout: Workout) {
  startLongPress({ type: 'saved', workout })
}

function onTouchEnd() {
  cancelLongPress()
}

function onSavedClick(workout: Workout) {
  if (longPressHandled.value) {
    longPressHandled.value = false
    return
  }
  cancelLongPress()
  loadSavedWorkout(workout)
}

// Mouse long-press (desktop): mousedown start, mouseup/mouseleave cancel
function onSavedMouseDown(workout: Workout) {
  startLongPress({ type: 'saved', workout })
}

function onMouseUp() {
  cancelLongPress()
}

function onMouseLeave() {
  cancelLongPress()
}

// Clean up long-press timer on unmount to avoid state updates after component is destroyed
onUnmounted(() => {
  cancelLongPress()
})

const deleteModalTitle = computed(() => 'Delete workout?')

const deleteTargetName = computed(() =>
  deleteTarget.value?.type === 'saved' ? deleteTarget.value.workout.name : ''
)

function closeDeleteModal() {
  showDeleteModal.value = false
  deleteTarget.value = null
  deleteError.value = null
  longPressHandled.value = false
}

async function confirmDelete() {
  const target = deleteTarget.value
  if (!target) return

  isDeleting.value = true
  deleteError.value = null

  try {
    await deleteWorkout(target.workout.id)
    myWorkouts.value = myWorkouts.value.filter((w) => w.id !== target.workout.id)
    closeDeleteModal()
  } catch (err) {
    deleteError.value = err instanceof Error ? err.message : 'Failed to delete'
  } finally {
    isDeleting.value = false
  }
}

const handleParse = async () => {
  if (!workoutText.value.trim()) return

  try {
    const parsed = await workoutStore.parseWorkout(workoutText.value)
    timerStore.setConfig(parsed.timer_config)
  } catch (error) {
    console.error('Failed to parse workout:', error)
  }
}

const emit = defineEmits<{
  workoutParsed: []
}>()

const parseAndNavigate = async () => {
  await handleParse()
  if (workoutStore.currentWorkout) {
    emit('workoutParsed')
  }
}
</script>

<template>
  <div class="space-y-6">
    <Card class="p-6 bg-card-elevated border-border/50 shadow-lg">
      <div class="space-y-4">
        <div>
          <label class="text-sm font-medium mb-2 block font-athletic">Create your timer.</label>
          <Textarea
            v-model="workoutText"
            placeholder="Describe your workout and we'll generate a custom timer for you."
            class="min-h-[120px] font-mono"
          />
        </div>

        <div class="flex flex-col gap-2">
          <Button
            @click="parseAndNavigate"
            :disabled="!workoutText.trim() || workoutStore.isLoading"
            variant="magic"
            class="w-full rounded-full"
          >
            <Loader2 v-if="workoutStore.isLoading" class="mr-2 h-4 w-4 animate-spin" />
            <Sparkles v-else class="mr-2 h-4 w-4" />
            {{ workoutStore.isLoading ? 'Creating...' : 'AI timer' }}
          </Button>
          
          <div v-if="workoutStore.isLoading" class="text-xs text-center text-muted-foreground">
            Your custom timer is being created...
          </div>
        </div>

        <div v-if="workoutStore.error" class="text-sm text-destructive">
          {{ workoutStore.error }}
        </div>
      </div>
    </Card>

    <div class="space-y-3">
      <h3 class="text-sm font-medium font-athletic">Saved Timers</h3>
      <p v-if="authStore.isAuthenticated && myWorkoutsLoading" class="text-sm text-muted-foreground">Loading...</p>
      <p v-else-if="myWorkoutsError" class="text-sm text-destructive">{{ myWorkoutsError }}</p>
      <div class="grid grid-cols-2 gap-2">
        <Button
          v-for="workout in displayedSavedWorkouts"
          :key="workout.id"
          variant="outline"
          size="sm"
          class="truncate"
          :title="workout.name"
          @click="onSavedClick(workout)"
          @touchstart.passive="onSavedTouchStart(workout)"
          @touchend="onTouchEnd"
          @touchcancel="onTouchEnd"
          @mousedown="onSavedMouseDown(workout)"
          @mouseup="onMouseUp"
          @mouseleave="onMouseLeave"
        >
          {{ displayName(workout.name) }}
        </Button>
      </div>
      <p
        v-if="authStore.isAuthenticated && savedWorkoutsOverflowCount > 0"
        class="text-sm text-muted-foreground mt-2"
      >
        <button
          type="button"
          @click="router.push('/workouts')"
          class="underline hover:text-foreground"
        >
          View all {{ myWorkouts.length }} workouts
        </button>
      </p>
    </div>

    <!-- Long-press delete confirmation -->
    <BottomSheet
      :open="showDeleteModal"
      :title="deleteModalTitle"
      @update:open="(val) => !val && closeDeleteModal()"
    >
      <div class="space-y-4">
        <p class="text-foreground">
          Are you sure you want to delete <strong>{{ deleteTargetName }}</strong>? This cannot be undone.
        </p>
        <div
          v-if="deleteError"
          class="px-3 py-2 bg-destructive/20 border border-destructive/30 text-destructive rounded-lg text-sm"
        >
          {{ deleteError }}
        </div>
      </div>
      <template #actions>
        <div class="flex gap-3">
          <button
            type="button"
            @click="closeDeleteModal"
            class="flex-1 px-4 py-2 border border-border rounded-lg text-foreground hover:bg-surface transition-colors"
            :disabled="isDeleting"
          >
            Cancel
          </button>
          <button
            type="button"
            @click="confirmDelete"
            class="flex-1 px-4 py-2 bg-destructive text-destructive-foreground rounded-lg hover:bg-destructive/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            :disabled="isDeleting"
          >
            {{ isDeleting ? 'Deleting...' : 'Delete' }}
          </button>
        </div>
      </template>
    </BottomSheet>

  </div>
</template>
