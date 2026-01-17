<script setup lang="ts">
import { computed } from 'vue'
import { useTimerStore } from '@/stores/timerStore'
import { storeToRefs } from 'pinia'
import { formatTimeDetailed, formatTime } from '@/lib/utils'

const timerStore = useTimerStore()
const { currentTime, intervalTime, config, isCompleted, isPreparing, prepTime, prepDuration, isIntervalBased, currentInterval, currentIntervalIndex, totalIntervals } = storeToRefs(timerStore)

const displayTime = computed(() => {
  if (isPreparing.value) {
    const remaining = prepDuration.value - prepTime.value
    return remaining.toString()
  }

  if (isIntervalBased.value && currentInterval.value) {
    // For interval-based workouts (EMOM, Tabata), show countdown in MM:SS format
    const remaining = currentInterval.value.duration - intervalTime.value
    return formatTime(remaining)
  }

  if (config.value?.type === 'countdown' && config.value?.total_seconds) {
    return formatTimeDetailed(config.value.total_seconds - currentTime.value)
  }
  return formatTimeDetailed(currentTime.value)
})

const timeClass = computed(() => {
  if (isPreparing.value) return 'text-blue-500 animate-pulse'
  if (isCompleted.value) return 'text-green-500'

  if (isIntervalBased.value && currentInterval.value) {
    const remaining = currentInterval.value.duration - intervalTime.value
    if (remaining <= 3) return 'text-red-500 animate-pulse'
    if (currentInterval.value.type === 'rest') return 'text-blue-400'
    return 'text-foreground'
  }

  if (config.value?.total_seconds) {
    const remaining = config.value.total_seconds - currentTime.value
    if (remaining <= 10) return 'text-red-500 animate-pulse'
    if (remaining <= 30) return 'text-orange-500'
  }

  return 'text-foreground'
})

const displayLabel = computed(() => {
  if (isPreparing.value) return 'Get Ready'
  if (isCompleted.value) return 'Complete!'

  if (isIntervalBased.value && currentInterval.value) {
    return currentInterval.value.label
  }

  return null
})

const intervalProgress = computed(() => {
  if (!isIntervalBased.value || !currentInterval.value) return 0
  return (intervalTime.value / currentInterval.value.duration) * 100
})

const showIntervalInfo = computed(() => {
  return isIntervalBased.value && currentInterval.value && !isPreparing.value
})

const intervalCounter = computed(() => {
  if (!isIntervalBased.value) return ''
  return `${currentIntervalIndex.value + 1}/${totalIntervals.value}`
})

const totalTimeDisplay = computed(() => {
  if (!config.value?.total_seconds) return ''
  return formatTime(currentTime.value)
})
</script>

<template>
  <div class="flex flex-col items-center justify-center space-y-4">
    <!-- Interval Label -->
    <div v-if="displayLabel" class="text-2xl md:text-3xl font-semibold text-muted-foreground">
      {{ displayLabel }}
    </div>

    <!-- Main Timer Display -->
    <div :class="['text-8xl md:text-9xl font-bold tabular-nums tracking-tight', timeClass]">
      {{ displayTime }}
    </div>

    <!-- Interval Progress Bar -->
    <div v-if="showIntervalInfo" class="w-full max-w-2xl space-y-2">
      <div class="h-3 bg-muted rounded-full overflow-hidden">
        <div
          :class="['h-full transition-all duration-300 ease-linear', currentInterval?.type === 'rest' ? 'bg-blue-400' : 'bg-primary']"
          :style="{ width: `${intervalProgress}%` }"
        />
      </div>

      <!-- Interval Counter and Total Time -->
      <div class="flex justify-between text-sm text-muted-foreground">
        <span class="font-medium">Set {{ intervalCounter }}</span>
        <span>Total: {{ totalTimeDisplay }}</span>
      </div>
    </div>

    <!-- Regular Progress Bar (for non-interval workouts) -->
    <div v-else-if="config?.total_seconds && !isPreparing" class="w-full max-w-2xl">
      <div class="h-2 bg-muted rounded-full overflow-hidden">
        <div
          class="h-full bg-primary transition-all duration-300 ease-linear"
          :style="{ width: `${timerStore.progress}%` }"
        />
      </div>
    </div>
  </div>
</template>
