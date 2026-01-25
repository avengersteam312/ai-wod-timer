<script setup lang="ts">
import { computed, ref } from 'vue'
import { useWorkoutStore } from '@/stores/workoutStore'
import { useTimerStore } from '@/stores/timerStore'
import { storeToRefs } from 'pinia'
import BottomSheet from '@/components/ui/BottomSheet.vue'

const workoutStore = useWorkoutStore()
const timerStore = useTimerStore()
const { currentWorkout } = storeToRefs(workoutStore)
const { manualRounds } = storeToRefs(timerStore)

const workoutNotes = computed(() => currentWorkout.value?.notes)
const showNotesSheet = ref(false)

const timeCap = computed(() => {
  const secs = currentWorkout.value?.time_cap
  if (!secs) return null
  const mins = Math.floor(secs / 60)
  const remainingSecs = secs % 60
  if (remainingSecs === 0) return `${mins} min`
  return `${mins}:${String(remainingSecs).padStart(2, '0')}`
})

// Format seconds to MM:SS
const formatTime = (seconds: number) => {
  const mins = Math.floor(seconds / 60)
  const secs = seconds % 60
  return `${mins}:${String(secs).padStart(2, '0')}`
}

// Check if we have rounds to show
const hasRounds = computed(() => manualRounds.value.length > 0)
</script>

<template>
  <div v-if="currentWorkout">
    <!-- Show workout toggle - always visible -->
    <button
      @click="showNotesSheet = true"
      class="w-full flex flex-col items-center py-2 text-muted-foreground hover:text-foreground transition-colors"
    >
      <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
        <path stroke-linecap="round" stroke-linejoin="round" d="M5 15l7-7 7 7" />
      </svg>
      <span class="text-xs">Show workout</span>
    </button>

    <!-- Workout Details Bottom Sheet -->
    <BottomSheet v-model:open="showNotesSheet" size="full" :show-handle="false">
      <!-- Hide workout at top -->
      <button
        @click="showNotesSheet = false"
        class="w-full flex flex-col items-center pb-4 text-muted-foreground hover:text-foreground transition-colors"
      >
        <span class="text-xs">Hide workout</span>
        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          <path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      <!-- Time cap if available -->
      <div v-if="timeCap" class="flex flex-wrap gap-2 mb-3">
        <span class="text-xs bg-surface-elevated px-2 py-1 rounded-md text-muted-foreground">
          Cap: {{ timeCap }}
        </span>
      </div>

      <!-- Content: Notes (left) + Rounds Timeline (right) -->
      <div class="flex gap-4">
        <!-- Notes (left side, max 70% width) -->
        <div class="flex-1 max-w-[70%]">
          <p v-if="workoutNotes" class="text-base text-foreground whitespace-pre-wrap">
            {{ workoutNotes }}
          </p>
        </div>

        <!-- Vertical Rounds Timeline (always right side) -->
        <div v-if="hasRounds" class="flex-shrink-0">
          <div class="flex flex-col items-center">
            <div
              v-for="(round, index) in manualRounds"
              :key="round.roundNumber"
              class="flex flex-col items-center"
            >
              <!-- Round circle -->
              <div class="flex items-center gap-2">
                <div class="w-8 h-8 rounded-full bg-primary/20 flex items-center justify-center">
                  <span class="text-xs font-bold text-primary">{{ round.roundNumber }}</span>
                </div>
                <div class="text-right">
                  <div class="text-sm font-medium text-foreground">{{ formatTime(round.duration) }}</div>
                  <div class="text-[10px] text-muted-foreground">@ {{ formatTime(round.completedAt) }}</div>
                </div>
              </div>
              <!-- Connector line -->
              <div
                v-if="index < manualRounds.length - 1"
                class="w-px h-4 bg-border my-1"
              />
            </div>
          </div>
        </div>
      </div>
    </BottomSheet>
  </div>
</template>
