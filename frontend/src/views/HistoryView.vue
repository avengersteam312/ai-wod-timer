<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ArrowLeft, History, Loader2, Clock, Trophy, Timer } from 'lucide-vue-next'
import ProfileMenu from '@/components/ProfileMenu.vue'
import BottomNav from '@/components/BottomNav.vue'
import OfflineIndicator from '@/components/OfflineIndicator.vue'
import Card from '@/components/ui/Card.vue'
import { getSessionHistory, type Session } from '@/services/sessionService'

const router = useRouter()

const sessions = ref<Session[]>([])
const isLoading = ref(true)
const error = ref<string | null>(null)

// Computed stats - only completed sessions
const completedSessions = computed(() =>
  sessions.value.filter(s => s.status === 'completed')
)

const totalWorkouts = computed(() => completedSessions.value.length)

const totalTimeSeconds = computed(() =>
  completedSessions.value.reduce((sum, s) => sum + (s.duration_seconds ?? 0), 0)
)

const formattedTotalTime = computed(() => {
  const total = totalTimeSeconds.value
  const hours = Math.floor(total / 3600)
  const minutes = Math.floor((total % 3600) / 60)

  if (hours > 0) {
    return `${hours}h ${minutes}m`
  }
  return `${minutes}m`
})

const loadSessions = async () => {
  isLoading.value = true
  error.value = null

  try {
    sessions.value = await getSessionHistory()
  } catch (err) {
    error.value = err instanceof Error ? err.message : 'Failed to load history'
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

const formatTime = (dateString: string): string => {
  const date = new Date(dateString)
  return date.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true
  })
}

const formatDuration = (seconds: number | null): string => {
  if (!seconds) return '--:--'

  const mins = Math.floor(seconds / 60)
  const secs = seconds % 60
  return `${mins}:${secs.toString().padStart(2, '0')}`
}

const getWorkoutName = (session: Session): string => {
  const snapshot = session.workout_snapshot
  // First try explicit name, then generate from workout type
  if (snapshot.name) return snapshot.name

  // Generate name from workout type
  const type = snapshot.workout_type
  const typeNames: Record<string, string> = {
    amrap: 'AMRAP Workout',
    emom: 'EMOM Workout',
    for_time: 'For Time Workout',
    tabata: 'Tabata Workout',
    intervals: 'Interval Training',
    stopwatch: 'Stopwatch Session',
    work_rest: 'Work & Rest',
    rest: 'Rest Timer',
    custom: 'Custom Workout'
  }
  return typeNames[type] || 'Workout'
}

const getWorkoutType = (session: Session): string => {
  return session.workout_snapshot.workout_type.toUpperCase()
}

const getStatusBadge = (status: Session['status']): { text: string; class: string } => {
  switch (status) {
    case 'completed':
      return { text: 'Completed', class: 'bg-timer-complete/10 text-timer-complete' }
    case 'abandoned':
      return { text: 'Abandoned', class: 'bg-destructive/10 text-destructive' }
    case 'in_progress':
      return { text: 'In Progress', class: 'bg-primary/10 text-primary' }
    default:
      return { text: status, class: 'bg-muted text-muted-foreground' }
  }
}

const handleBack = () => {
  router.push('/')
}

onMounted(() => {
  loadSessions()
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
            Workout History
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
            @click="loadSessions"
            class="px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors"
          >
            Try Again
          </button>
        </div>

        <!-- Empty State -->
        <div
          v-else-if="sessions.length === 0"
          class="flex-1 flex flex-col items-center justify-center text-center"
        >
          <div class="w-16 h-16 bg-surface rounded-full flex items-center justify-center mb-4">
            <History class="h-8 w-8 text-muted-foreground" />
          </div>
          <h2 class="text-lg font-semibold text-foreground mb-2">No Workout History</h2>
          <p class="text-muted-foreground mb-6">
            Complete a workout to see your history here
          </p>
          <button
            @click="handleBack"
            class="px-4 py-2 bg-primary text-primary-foreground rounded-lg hover:bg-primary/90 transition-colors"
          >
            Start a Workout
          </button>
        </div>

        <!-- Stats & Sessions -->
        <div v-else class="space-y-4">
          <!-- Stats Cards -->
          <div class="grid grid-cols-2 gap-3">
            <Card class="p-4">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 bg-primary/10 rounded-full flex items-center justify-center">
                  <Trophy class="h-5 w-5 text-primary" />
                </div>
                <div>
                  <p class="text-2xl font-bold text-foreground">{{ totalWorkouts }}</p>
                  <p class="text-xs text-muted-foreground">Workouts</p>
                </div>
              </div>
            </Card>
            <Card class="p-4">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 bg-timer-complete/10 rounded-full flex items-center justify-center">
                  <Timer class="h-5 w-5 text-timer-complete" />
                </div>
                <div>
                  <p class="text-2xl font-bold text-foreground">{{ formattedTotalTime }}</p>
                  <p class="text-xs text-muted-foreground">Total Time</p>
                </div>
              </div>
            </Card>
          </div>

          <!-- Session List -->
          <div class="space-y-3">
            <h2 class="text-sm font-medium text-muted-foreground uppercase tracking-wide">
              Recent Sessions
            </h2>
            <Card
              v-for="session in sessions"
              :key="session.id"
              class="p-4"
            >
              <div class="flex items-start gap-3">
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2 mb-1">
                    <h3 class="font-medium text-foreground truncate">
                      {{ getWorkoutName(session) }}
                    </h3>
                    <span
                      :class="getStatusBadge(session.status).class"
                      class="px-2 py-0.5 text-xs font-medium rounded shrink-0"
                    >
                      {{ getStatusBadge(session.status).text }}
                    </span>
                  </div>
                  <div class="flex items-center gap-3 text-sm text-muted-foreground">
                    <span>{{ formatDate(session.started_at) }}</span>
                    <span>{{ formatTime(session.started_at) }}</span>
                  </div>
                </div>
                <div class="text-right shrink-0">
                  <div class="flex items-center gap-1 text-foreground">
                    <Clock class="h-4 w-4 text-muted-foreground" />
                    <span class="font-medium">{{ formatDuration(session.duration_seconds) }}</span>
                  </div>
                  <span class="text-xs text-primary font-medium">
                    {{ getWorkoutType(session) }}
                  </span>
                </div>
              </div>
            </Card>
          </div>
        </div>
      </main>
    </div>

    <!-- Bottom Navigation -->
    <BottomNav />
  </div>
</template>
