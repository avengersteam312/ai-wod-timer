<script setup lang="ts">
import Card from '@/components/ui/Card.vue'
import DurationInput from '../inputs/DurationInput.vue'

const props = defineProps<{
  minutes: number
  seconds: number
}>()

const emit = defineEmits<{
  'update:minutes': [value: number]
  'update:seconds': [value: number]
  quickStart: [seconds: number]
}>()

const restPresets = [
  { label: '30s', seconds: 30 },
  { label: '1 min', seconds: 60 },
  { label: '2 min', seconds: 120 },
  { label: '3 min', seconds: 180 },
  { label: '5 min', seconds: 300 }
]

const adjustDuration = (delta: number) => {
  let totalSec = props.minutes * 60 + props.seconds + delta
  totalSec = Math.min(99 * 60 + 59, Math.max(0, totalSec))
  emit('update:minutes', Math.floor(totalSec / 60))
  emit('update:seconds', totalSec % 60)
}
</script>

<template>
  <Card class="p-4 space-y-4">
    <label class="text-[10px] font-semibold tracking-wider text-muted-foreground block">
      QUICK SELECT
    </label>
    <div class="flex flex-wrap gap-2">
      <button
        v-for="preset in restPresets"
        :key="preset.seconds"
        @click="$emit('quickStart', preset.seconds)"
        class="px-4 py-2 rounded-lg text-sm font-medium transition-colors bg-primary text-primary-foreground hover:bg-primary/90"
        type="button"
      >
        {{ preset.label }}
      </button>
    </div>

    <DurationInput
      label="CUSTOM DURATION"
      :minutes="minutes"
      :seconds="seconds"
      :step="15"
      size="lg"
      @update:minutes="$emit('update:minutes', $event)"
      @update:seconds="$emit('update:seconds', $event)"
      @adjust="adjustDuration"
    />
  </Card>
</template>
