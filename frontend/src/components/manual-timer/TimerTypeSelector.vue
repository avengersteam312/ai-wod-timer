<script setup lang="ts">
import { Timer, Clock, Zap, Target, Flame, Settings, RefreshCw, Infinity } from 'lucide-vue-next'
import type { Component } from 'vue'
import type { TimerType } from './composables/useTimerConfigBuilder'

interface TimerTypeOption {
  value: TimerType
  label: string
  description: string
  icon: Component
}

defineEmits<{
  select: [type: TimerType]
  switchToAI: []
}>()

const timerTypes: TimerTypeOption[] = [
  { value: 'rest', label: 'Rest Timer', description: 'Quick rest between sets', icon: Timer },
  { value: 'work_rest', label: 'Work & Rest', description: 'Rest equals your work time', icon: RefreshCw },
  { value: 'amrap', label: 'AMRAP', description: 'As many rounds as possible', icon: Infinity },
  { value: 'for_time', label: 'For Time', description: 'Beat the clock', icon: Target },
  { value: 'tabata', label: 'Tabata', description: '20s work / 10s rest intervals', icon: Flame },
  { value: 'custom_interval', label: 'Custom Interval', description: 'Custom work/rest periods', icon: Settings },
  { value: 'emom', label: 'EMOM', description: 'Every minute on the minute', icon: Zap },
  { value: 'stopwatch', label: 'Stopwatch', description: 'Count up from zero', icon: Clock }
]
</script>

<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="text-center">
      <h1 class="text-4xl font-bold tracking-tight mb-2">Manual Timer</h1>
      <p class="text-muted-foreground">Select a timer type</p>
    </div>

    <!-- Timer Type List -->
    <div class="space-y-2">
      <button
        v-for="type in timerTypes"
        :key="type.value"
        @click="$emit('select', type.value)"
        class="w-full flex items-center gap-4 p-4 rounded-xl bg-surface border border-border hover:bg-surface-elevated hover:border-primary/50 transition-colors text-left"
      >
        <div class="w-12 h-12 rounded-lg bg-primary/10 flex items-center justify-center text-primary">
          <component :is="type.icon" class="w-6 h-6" />
        </div>
        <div class="flex-1">
          <h3 class="font-semibold text-foreground">{{ type.label }}</h3>
          <p class="text-sm text-muted-foreground">{{ type.description }}</p>
        </div>
        <svg class="w-5 h-5 text-muted-foreground" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
        </svg>
      </button>
    </div>

    <!-- Switch to AI mode link -->
    <div class="text-center pt-4">
      <button
        @click="$emit('switchToAI')"
        class="text-muted-foreground hover:text-foreground text-sm transition-colors"
      >
        Or parse from text →
      </button>
    </div>
  </div>
</template>
