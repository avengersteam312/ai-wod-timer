import { computed } from 'vue'
import { useWorkoutStore } from '@/stores/workoutStore'
import { storeToRefs } from 'pinia'
import { getTimerLayoutConfig, type TimerLayoutConfig } from '@/components/timer/config/timerLayoutConfig'

export function useTimerLayout() {
  const workoutStore = useWorkoutStore()
  const { currentWorkout } = storeToRefs(workoutStore)

  const layoutConfig = computed<TimerLayoutConfig>(() => {
    if (!currentWorkout.value) {
      return {
        showTimerBlock: true,
        showCurrentMovement: true,
        showNextMovement: true,
        showControls: true,
        showProgress: true,
        showCompletedCard: true,
        showWorkoutSummary: true,
        showRoundCounter: true
      }
    }
    return getTimerLayoutConfig(currentWorkout.value.workout_type)
  })

  const showTimerBlock = computed(() => layoutConfig.value.showTimerBlock)
  const showCurrentMovement = computed(() => layoutConfig.value.showCurrentMovement)
  const showNextMovement = computed(() => layoutConfig.value.showNextMovement)
  const showControls = computed(() => layoutConfig.value.showControls)
  const showProgress = computed(() => layoutConfig.value.showProgress)
  const showCompletedCard = computed(() => layoutConfig.value.showCompletedCard)
  const showWorkoutSummary = computed(() => layoutConfig.value.showWorkoutSummary)
  const showRoundCounter = computed(() => layoutConfig.value.showRoundCounter)

  return {
    layoutConfig,
    showTimerBlock,
    showCurrentMovement,
    showNextMovement,
    showControls,
    showProgress,
    showCompletedCard,
    showWorkoutSummary,
    showRoundCounter
  }
}
