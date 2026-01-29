<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ArrowLeft, Dumbbell, Loader2, Star, Trash2 } from 'lucide-vue-next'
import ProfileMenu from '@/components/ProfileMenu.vue'
import BottomNav from '@/components/BottomNav.vue'
import OfflineIndicator from '@/components/OfflineIndicator.vue'
import Card from '@/components/ui/Card.vue'
import BottomSheet from '@/components/ui/BottomSheet.vue'
import { getWorkouts, updateWorkout, deleteWorkout, type Workout } from '@/services/workoutService'
import { useWorkoutStore } from '@/stores/workoutStore'

const router = useRouter()
const workoutStore = useWorkoutStore()

const workouts = ref<Workout[]>([])
const isLoading = ref(true)
const error = ref<string | null>(null)

// Delete confirmation state
const showDeleteModal = ref(false)
const workoutToDelete = ref<Workout | null>(null)
const isDeleting = ref(false)
const deleteError = ref<string | null>(null)

// Favorite toggle loading state
const favoriteLoading = ref<string | null>(null)

const loadWorkouts = async () => {
  isLoading.value = true
  error.value = null

  try {
    workouts.value = await getWorkouts()
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Failed to load workouts'
  } finally {
    isLoading.value = false
  }
}

const formatDate = (dateString: string): string => {
  const date = new Date(dateString)
  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric'
  })
}

const handleBack = () => {
  router.push('/')
}

const handleLoadWorkout = (workout: Workout) => {
  // Load the workout's parsed config into the workout store
  workoutStore.setManualWorkout(workout.parsed_config)
  // Navigate to timer view
  router.push('/')
}

const handleToggleFavorite = async (workout: Workout, event: Event) => {
  event.stopPropagation() // Prevent card click

  favoriteLoading.value = workout.id
  try {
    const result = await updateWorkout(workout.id, { is_favorite: !workout.is_favorite })
    // Update local state
    const index = workouts.value.findIndex(w => w.id === workout.id)
    if (index !== -1) {
      workouts.value[index] = result.workout
    }
  } catch (err) {
    // Silently fail - user can retry
    console.error('Failed to toggle favorite:', err)
  } finally {
    favoriteLoading.value = null
  }
}

const openDeleteModal = (workout: Workout, event: Event) => {
  event.stopPropagation() // Prevent card click
  workoutToDelete.value = workout
  deleteError.value = null
  showDeleteModal.value = true
}

const closeDeleteModal = () => {
  showDeleteModal.value = false
  workoutToDelete.value = null
  deleteError.value = null
}

const handleDelete = async () => {
  if (!workoutToDelete.value) return

  isDeleting.value = true
  deleteError.value = null

  try {
    await deleteWorkout(workoutToDelete.value.id)
    // Remove from local state
    workouts.value = workouts.value.filter(w => w.id !== workoutToDelete.value?.id)
    closeDeleteModal()
  } catch (err) {
    deleteError.value = err instanceof Error ? err.message : 'Failed to delete workout'
  } finally {
    isDeleting.value = false
  }
}

onMounted(() => {
  loadWorkouts()
})
</script>

<template>
  <div class="min-h-screen bg-background">
    <div class="min-h-screen flex flex-col max-w-md mx-auto">
      <!-- Header -->
      <header class="flex items-center justify-between px-4 py-3">
        <button
          @click="handleBack"
          class="p-2 -ml-2 text-foreground hover:text-muted-foreground transition-colors"
          aria-label="Back"
        >
          <ArrowLeft class="h-6 w-6" />
        </button>

        <div class="flex items-center gap-2">
          <h1 class="text-base font-semibold text-foreground font-athletic">
            My Workouts
          </h1>
          <OfflineIndicator />
        </div>

        <ProfileMenu />
      </header>

      <!-- Main Content -->
      <main class="flex-1 flex flex-col px-4 pb-20">
        <!-- Loading State -->
        <div v-if="isLoading" class="flex-1 flex items-center justify-center">
          <Loader2 class="h-8 w-8 text-muted-foreground animate-spin" />
        </div>

        <!-- Error State -->
        <div
          v-else-if="error"
          class="flex-1 flex flex-col items-center justify-center text-center"
        >
          <p class="text-destructive mb-4">{{ error }}</p>
          <button
            @click="loadWorkouts"
            class="px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors"
          >
            Try Again
          </button>
        </div>

        <!-- Empty State -->
        <div
          v-else-if="workouts.length === 0"
          class="flex-1 flex flex-col items-center justify-center text-center"
        >
          <div class="w-16 h-16 bg-surface rounded-full flex items-center justify-center mb-4">
            <Dumbbell class="h-8 w-8 text-muted-foreground" />
          </div>
          <h2 class="text-lg font-semibold text-foreground mb-2">No Workouts Saved</h2>
          <p class="text-muted-foreground mb-6">
            Save your workouts from the timer to see them here
          </p>
          <button
            @click="handleBack"
            class="px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors"
          >
            Create a Workout
          </button>
        </div>

        <!-- Workout List -->
        <div v-else class="space-y-3">
          <Card
            v-for="workout in workouts"
            :key="workout.id"
            class="p-4 cursor-pointer hover:bg-surface/50 transition-colors"
            @click="handleLoadWorkout(workout)"
          >
            <div class="flex items-center gap-3">
              <div class="flex-1 min-w-0">
                <h3 class="font-medium text-foreground truncate">
                  {{ workout.name }}
                </h3>
                <p class="text-sm text-muted-foreground">
                  {{ formatDate(workout.created_at) }}
                </p>
              </div>
              <div
                class="px-2 py-1 bg-primary/10 text-primary text-xs font-medium rounded shrink-0"
              >
                {{ workout.parsed_config.workout_type.toUpperCase() }}
              </div>
              <!-- Favorite Toggle -->
              <button
                @click="handleToggleFavorite(workout, $event)"
                :disabled="favoriteLoading === workout.id"
                class="p-2 -m-2 transition-colors shrink-0"
                :class="[
                  workout.is_favorite
                    ? 'text-yellow-500 hover:text-yellow-600'
                    : 'text-muted-foreground hover:text-foreground'
                ]"
                :aria-label="workout.is_favorite ? 'Remove from favorites' : 'Add to favorites'"
              >
                <Star
                  class="h-5 w-5"
                  :class="{ 'fill-current': workout.is_favorite }"
                />
              </button>
              <!-- Delete Button -->
              <button
                @click="openDeleteModal(workout, $event)"
                class="p-2 -m-2 text-muted-foreground hover:text-destructive transition-colors shrink-0"
                aria-label="Delete workout"
              >
                <Trash2 class="h-5 w-5" />
              </button>
            </div>
          </Card>
        </div>
      </main>
    </div>

    <!-- Delete Confirmation Modal -->
    <BottomSheet
      :open="showDeleteModal"
      title="Delete Workout"
      @update:open="(val) => !val && closeDeleteModal()"
    >
      <div class="space-y-4">
        <p class="text-foreground">
          Are you sure you want to delete <strong>{{ workoutToDelete?.name }}</strong>? This action cannot be undone.
        </p>

        <!-- Error message -->
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
            @click="closeDeleteModal"
            class="flex-1 px-4 py-2 border border-border rounded-lg text-foreground hover:bg-surface transition-colors"
            :disabled="isDeleting"
          >
            Cancel
          </button>
          <button
            @click="handleDelete"
            class="flex-1 px-4 py-2 bg-destructive text-destructive-foreground rounded-lg hover:bg-destructive/90 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            :disabled="isDeleting"
          >
            {{ isDeleting ? 'Deleting...' : 'Delete' }}
          </button>
        </div>
      </template>
    </BottomSheet>

    <!-- Bottom Navigation -->
    <BottomNav />
  </div>
</template>
