<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'

interface Props {
  durationMs: number
  isRunning: boolean
  size?: number
  strokeWidth?: number
  onComplete?: () => void
  initialElapsedMs?: number
  showSeconds?: boolean
  snakeMode?: boolean
  segmentFraction?: number // For snake mode: fraction of circle to show (0-1)
}

const props = withDefaults(defineProps<Props>(), {
  size: 200,
  strokeWidth: 8,
  initialElapsedMs: 0,
  showSeconds: true,
  snakeMode: false,
  segmentFraction: 0.15, // Show 15% of circle in snake mode
})

// Monotonic time tracking
const startTime = ref<number | null>(null)
const accumulatedElapsedMs = ref(props.initialElapsedMs)
const animationFrameId = ref<number | null>(null)
const hasCompleted = ref(false)

// Computed values
const radius = computed(() => (props.size - props.strokeWidth) / 2)
const circumference = computed(() => 2 * Math.PI * radius.value)

// Current progress (0-1)
const progress = computed(() => {
  if (!props.isRunning && startTime.value === null) {
    // Not started yet
    return accumulatedElapsedMs.value / props.durationMs
  }
  
  const now = performance.now()
  const elapsed = accumulatedElapsedMs.value + (startTime.value ? now - startTime.value : 0)
  return Math.min(1, Math.max(0, elapsed / props.durationMs))
})

// Remaining time in milliseconds
const remainingMs = computed(() => {
  const elapsed = accumulatedElapsedMs.value + (startTime.value ? performance.now() - startTime.value : 0)
  return Math.max(0, props.durationMs - elapsed)
})

// Display seconds (discrete, ticks once per second)
const remainingSeconds = computed(() => {
  return Math.max(0, Math.ceil(remainingMs.value / 1000))
})

// SVG stroke calculations
const strokeDasharray = computed(() => {
  if (props.snakeMode) {
    // In snake mode, dash array shows only a segment
    // Format: [visible segment] [gap to make it appear as a segment]
    const segmentLength = circumference.value * props.segmentFraction
    return `${segmentLength} ${circumference.value}`
  } else {
    // Full arc mode: full circle dash array
    return circumference.value.toString()
  }
})

const strokeDashoffset = computed(() => {
  if (props.snakeMode) {
    // Snake mode: position the segment based on progress
    // As progress goes from 0 to 1, the segment moves around the circle
    // Offset is calculated so the segment's head is at the progress position
    // We rotate the offset so the segment appears to "chase" the progress
    return circumference.value * (1 - progress.value)
  } else {
    // Full arc mode: standard progress
    return circumference.value * (1 - progress.value)
  }
})

// Watch for running state changes
watch(() => props.isRunning, (isRunning) => {
  if (isRunning) {
    // Start or resume
    if (startTime.value === null) {
      // First start
      startTime.value = performance.now()
    } else {
      // Resume: update accumulated time and reset start time
      const now = performance.now()
      accumulatedElapsedMs.value += now - startTime.value
      startTime.value = now
    }
    hasCompleted.value = false
    startAnimation()
  } else {
    // Pause
    if (startTime.value !== null) {
      const now = performance.now()
      accumulatedElapsedMs.value += now - startTime.value
      startTime.value = null
    }
    stopAnimation()
  }
})

// Watch for initialElapsedMs changes (external reset)
watch(() => props.initialElapsedMs, (newValue) => {
  accumulatedElapsedMs.value = newValue
  if (startTime.value !== null) {
    startTime.value = performance.now()
  }
  hasCompleted.value = false
})

// Animation loop
const animate = () => {
  if (!props.isRunning || startTime.value === null) {
    return
  }

  const now = performance.now()
  const elapsed = accumulatedElapsedMs.value + (now - startTime.value)
  
  // Check for completion
  if (elapsed >= props.durationMs && !hasCompleted.value) {
    hasCompleted.value = true
    stopAnimation()
    props.onComplete?.()
    return
  }

  // Continue animation
  animationFrameId.value = requestAnimationFrame(animate)
}

const startAnimation = () => {
  if (animationFrameId.value === null) {
    animationFrameId.value = requestAnimationFrame(animate)
  }
}

const stopAnimation = () => {
  if (animationFrameId.value !== null) {
    cancelAnimationFrame(animationFrameId.value)
    animationFrameId.value = null
  }
}

// Initialize
onMounted(() => {
  if (props.isRunning) {
    startTime.value = performance.now()
    startAnimation()
  }
})

onUnmounted(() => {
  stopAnimation()
})
</script>

<template>
  <div class="relative flex items-center justify-center" :style="{ width: `${props.size}px`, height: `${props.size}px` }">
    <svg
      :width="props.size"
      :height="props.size"
      class="absolute transform -rotate-90"
    >
      <!-- Background Ring -->
      <circle
        :cx="props.size / 2"
        :cy="props.size / 2"
        :r="radius"
        fill="none"
        class="stroke-surface-elevated"
        :stroke-width="props.strokeWidth"
      />
      
      <!-- Progress Ring -->
      <circle
        :cx="props.size / 2"
        :cy="props.size / 2"
        :r="radius"
        fill="none"
        class="stroke-primary"
        :stroke-width="props.strokeWidth"
        stroke-linecap="round"
        :stroke-dasharray="strokeDasharray"
        :stroke-dashoffset="strokeDashoffset"
        style="transition: none;"
      />
    </svg>

    <!-- Center Content -->
    <div class="absolute flex flex-col items-center justify-center text-center">
      <slot :remaining-seconds="remainingSeconds" :remaining-ms="remainingMs" :progress="progress">
        <div v-if="showSeconds" class="text-6xl font-bold tabular-nums tracking-tight text-foreground">
          {{ remainingSeconds }}
        </div>
      </slot>
    </div>
  </div>
</template>
