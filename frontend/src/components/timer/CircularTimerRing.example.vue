<!--
  Example usage of CircularTimerRing component
  
  This component provides smooth, Apple Workout-style timer ring animation
  with discrete second updates for the label.
-->

<script setup lang="ts">
import { ref } from 'vue'
import CircularTimerRing from './CircularTimerRing.vue'

// Example: 30 second countdown timer
const durationMs = 30 * 1000 // 30 seconds
const isRunning = ref(false)
const initialElapsedMs = ref(0)

const handleStart = () => {
  isRunning.value = true
}

const handlePause = () => {
  isRunning.value = false
}

const handleReset = () => {
  isRunning.value = false
  initialElapsedMs.value = 0
}

const handleComplete = () => {
  console.log('Timer completed!')
  isRunning.value = false
}

// Example: Snake mode (shows a moving segment instead of full arc)
const snakeMode = ref(false)
</script>

<template>
  <div class="p-8 space-y-8">
    <h1 class="text-2xl font-bold">CircularTimerRing Examples</h1>
    
    <!-- Standard Mode -->
    <div class="space-y-4">
      <h2 class="text-lg font-semibold">Standard Mode (Full Arc)</h2>
      <div class="flex flex-col items-center gap-4">
        <CircularTimerRing
          :duration-ms="durationMs"
          :is-running="isRunning"
          :initial-elapsed-ms="initialElapsedMs"
          :show-seconds="true"
          @complete="handleComplete"
        />
        
        <div class="flex gap-2">
          <button
            @click="handleStart"
            :disabled="isRunning"
            class="px-4 py-2 bg-primary text-primary-foreground rounded-md disabled:opacity-50"
          >
            Start
          </button>
          <button
            @click="handlePause"
            :disabled="!isRunning"
            class="px-4 py-2 bg-secondary text-secondary-foreground rounded-md disabled:opacity-50"
          >
            Pause
          </button>
          <button
            @click="handleReset"
            class="px-4 py-2 bg-destructive text-destructive-foreground rounded-md"
          >
            Reset
          </button>
        </div>
      </div>
    </div>

    <!-- Snake Mode -->
    <div class="space-y-4">
      <h2 class="text-lg font-semibold">Snake Mode (Moving Segment)</h2>
      <div class="flex items-center gap-2 mb-4">
        <input
          type="checkbox"
          id="snake-mode"
          v-model="snakeMode"
        />
        <label for="snake-mode">Enable snake mode</label>
      </div>
      
      <div class="flex flex-col items-center gap-4">
        <CircularTimerRing
          :duration-ms="durationMs"
          :is-running="isRunning"
          :initial-elapsed-ms="initialElapsedMs"
          :show-seconds="true"
          :snake-mode="snakeMode"
          :segment-fraction="0.15"
          @complete="handleComplete"
        />
      </div>
    </div>

    <!-- Custom Content Slot -->
    <div class="space-y-4">
      <h2 class="text-lg font-semibold">Custom Content Slot</h2>
      <div class="flex flex-col items-center gap-4">
        <CircularTimerRing
          :duration-ms="durationMs"
          :is-running="isRunning"
          :initial-elapsed-ms="initialElapsedMs"
          :show-seconds="false"
          @complete="handleComplete"
        >
          <template #default="{ remainingSeconds, remainingMs, progress }">
            <div class="text-center">
              <div class="text-6xl font-bold tabular-nums">
                {{ remainingSeconds }}
              </div>
              <div class="text-sm text-muted-foreground mt-2">
                {{ Math.round(progress * 100) }}% complete
              </div>
              <div class="text-xs text-muted-foreground mt-1">
                {{ Math.round(remainingMs) }}ms remaining
              </div>
            </div>
          </template>
        </CircularTimerRing>
      </div>
    </div>
  </div>
</template>
