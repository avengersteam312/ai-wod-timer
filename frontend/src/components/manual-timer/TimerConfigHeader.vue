<script setup lang="ts">
import { computed } from 'vue'
import { ArrowLeft } from 'lucide-vue-next'
import type { TimerType } from './composables/useTimerConfigBuilder'
import { selectOnFocus } from './composables/useInputHandlers'

const props = defineProps<{
  type: TimerType
  countdown: number
}>()

const emit = defineEmits<{
  back: []
  'update:countdown': [value: number]
}>()

const typeInfo: Record<TimerType, { label: string; description: string }> = {
  rest: { label: 'Rest Timer', description: 'Quick rest between sets' },
  work_rest: { label: 'Work & Rest', description: 'Rest equals your work time' },
  amrap: { label: 'AMRAP', description: 'As many rounds as possible' },
  for_time: { label: 'For Time', description: 'Beat the clock' },
  tabata: { label: 'Tabata', description: '20s work / 10s rest intervals' },
  custom_interval: { label: 'Custom Interval', description: 'Custom work/rest periods' },
  emom: { label: 'EMOM', description: 'Every minute on the minute' },
  stopwatch: { label: 'Stopwatch', description: 'Count up from zero' }
}

const currentTypeInfo = computed(() => typeInfo[props.type])

// Rest timer doesn't have countdown
const hasCountdown = computed(() => props.type !== 'rest')

const adjustCountdown = (delta: number) => {
  const newValue = props.countdown + delta
  if (newValue >= 0 && newValue <= 30) {
    emit('update:countdown', newValue)
  }
}

const onCountdownBlur = (e: Event) => {
  const val = parseInt((e.target as HTMLInputElement).value) || 0
  emit('update:countdown', Math.min(30, Math.max(0, val)))
}
</script>

<template>
  <div class="flex items-center justify-between">
    <div class="flex items-center gap-3">
      <button
        @click="$emit('back')"
        class="p-2 -ml-2 text-muted-foreground hover:text-foreground transition-colors"
        type="button"
      >
        <ArrowLeft class="w-5 h-5" />
      </button>
      <div>
        <h1 class="text-2xl font-bold font-athletic">{{ currentTypeInfo.label }}</h1>
        <p class="text-sm text-muted-foreground">{{ currentTypeInfo.description }}</p>
      </div>
    </div>

    <!-- Countdown input -->
    <div v-if="hasCountdown" class="flex items-center gap-2">
      <button
        @click="adjustCountdown(-1)"
        class="w-7 h-7 rounded-md bg-surface-elevated flex items-center justify-center text-muted-foreground hover:text-foreground"
        type="button"
      >
        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4"/>
        </svg>
      </button>
      <div class="text-center min-w-[50px]">
        <div class="flex items-center justify-center">
          <input
            type="text"
            inputmode="numeric"
            :value="countdown"
            @blur="onCountdownBlur"
            @focus="selectOnFocus"
            maxlength="2"
            aria-label="Countdown seconds"
            class="w-8 text-lg font-bold text-center bg-transparent outline-none"
          />
          <span class="text-lg font-bold">s</span>
        </div>
        <p class="text-[9px] text-muted-foreground">countdown</p>
      </div>
      <button
        @click="adjustCountdown(1)"
        class="w-7 h-7 rounded-md bg-surface-elevated flex items-center justify-center text-muted-foreground hover:text-foreground"
        type="button"
      >
        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
      </button>
    </div>
  </div>
</template>
