<script setup lang="ts">
import { computed } from 'vue'
import Card from '@/components/ui/Card.vue'
import DurationInput from '../inputs/DurationInput.vue'

const props = defineProps<{
  type: 'amrap' | 'for_time'
  minutes: number
  seconds: number
}>()

const emit = defineEmits<{
  'update:minutes': [value: number]
  'update:seconds': [value: number]
}>()

const totalSeconds = computed(() => props.minutes * 60 + props.seconds)

const adjustDuration = (delta: number) => {
  let totalSec = props.minutes * 60 + props.seconds + delta
  totalSec = Math.min(99 * 60 + 59, Math.max(0, totalSec))
  emit('update:minutes', Math.floor(totalSec / 60))
  emit('update:seconds', totalSec % 60)
}

const description = computed(() => {
  if (props.type === 'amrap') {
    return 'Complete as many rounds as possible'
  }
  if (totalSeconds.value === 0) {
    return 'Timer counts up until you finish'
  }
  return 'Complete the workout before time runs out'
})
</script>

<template>
  <Card class="p-4 space-y-4">
    <DurationInput
      :label="type === 'for_time' ? 'TIME CAP (optional)' : 'TIME CAP'"
      :minutes="minutes"
      :seconds="seconds"
      :step="60"
      size="lg"
      @update:minutes="$emit('update:minutes', $event)"
      @update:seconds="$emit('update:seconds', $event)"
      @adjust="adjustDuration"
    />
    <p class="text-xs text-muted-foreground text-center">
      {{ description }}
    </p>
  </Card>
</template>
