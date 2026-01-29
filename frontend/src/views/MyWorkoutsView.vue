<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ArrowLeft, Dumbbell, Loader2 } from 'lucide-vue-next'
import ProfileMenu from '@/components/ProfileMenu.vue'
import Card from '@/components/ui/Card.vue'
import { getWorkouts, type Workout } from '@/services/workoutService'

const router = useRouter()

const workouts = ref<Workout[]>([])
const isLoading = ref(true)
const error = ref<string | null>(null)

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

        <h1 class="text-base font-semibold text-foreground font-athletic">
          My Workouts
        </h1>

        <ProfileMenu />
      </header>

      <!-- Main Content -->
      <main class="flex-1 flex flex-col px-4 pb-4">
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
          >
            <div class="flex items-center justify-between">
              <div class="flex-1 min-w-0">
                <h3 class="font-medium text-foreground truncate">
                  {{ workout.name }}
                </h3>
                <p class="text-sm text-muted-foreground">
                  {{ formatDate(workout.created_at) }}
                </p>
              </div>
              <div
                class="ml-3 px-2 py-1 bg-primary/10 text-primary text-xs font-medium rounded"
              >
                {{ workout.parsed_config.workout_type.toUpperCase() }}
              </div>
            </div>
          </Card>
        </div>
      </main>
    </div>
  </div>
</template>
