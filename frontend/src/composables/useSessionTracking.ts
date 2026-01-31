import { ref, watch, onUnmounted } from 'vue'
import { useTimerStore, TimerState } from '@/stores/timerStore'
import { useWorkoutStore } from '@/stores/workoutStore'
import { storeToRefs } from 'pinia'
import { startSession, completeSession, abandonSession } from '@/services/sessionService'
import type { Session } from '@/services/sessionService'

/**
 * Composable for tracking workout sessions in the database.
 * Automatically starts a session when timer begins and completes it when finished.
 */
export function useSessionTracking() {
  const timerStore = useTimerStore()
  const workoutStore = useWorkoutStore()
  const { state, currentTime } = storeToRefs(timerStore)
  const { currentWorkout } = storeToRefs(workoutStore)

  const currentSession = ref<Session | null>(null)
  const sessionError = ref<string | null>(null)
  const isTracking = ref(false)

  // Start session when timer transitions to RUNNING (from PREPARING or direct start)
  const handleStartSession = async () => {
    if (!currentWorkout.value || currentSession.value || isTracking.value) return

    isTracking.value = true
    sessionError.value = null

    try {
      const session = await startSession(currentWorkout.value)
      currentSession.value = session
    } catch (err) {
      console.error('Failed to start session:', err)
      sessionError.value = err instanceof Error ? err.message : 'Failed to start session'
    } finally {
      isTracking.value = false
    }
  }

  // Complete session when timer transitions to COMPLETED
  const handleCompleteSession = async () => {
    if (!currentSession.value) return

    try {
      await completeSession(currentSession.value.id, currentTime.value)
      currentSession.value = null
    } catch (err) {
      console.error('Failed to complete session:', err)
      sessionError.value = err instanceof Error ? err.message : 'Failed to complete session'
    }
  }

  // Abandon session (e.g., when user navigates away or resets)
  const handleAbandonSession = async () => {
    if (!currentSession.value) return

    try {
      await abandonSession(currentSession.value.id)
      currentSession.value = null
    } catch (err) {
      console.error('Failed to abandon session:', err)
    }
  }

  // Watch timer state changes
  watch(state, async (newState, oldState) => {
    // Start session when timer starts running (either from PREPARING or IDLE)
    if (newState === TimerState.RUNNING && oldState !== TimerState.PAUSED && !currentSession.value) {
      await handleStartSession()
    }

    // Complete session when timer completes
    if (newState === TimerState.COMPLETED && currentSession.value) {
      await handleCompleteSession()
    }
  })

  // Reset session when workout is cleared
  watch(currentWorkout, (workout) => {
    if (!workout && currentSession.value) {
      // Workout was cleared - abandon the session if it wasn't completed
      handleAbandonSession()
    }
  })

  // Abandon session on unmount if still active
  onUnmounted(() => {
    if (currentSession.value) {
      handleAbandonSession()
    }
  })

  return {
    currentSession,
    sessionError,
    isTracking,
    abandonSession: handleAbandonSession
  }
}
