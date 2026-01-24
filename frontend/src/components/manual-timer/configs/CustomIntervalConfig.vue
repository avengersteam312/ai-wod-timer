<script setup lang="ts">
import Card from '@/components/ui/Card.vue'
import DurationInput from '../inputs/DurationInput.vue'
import NumberInput from '../inputs/NumberInput.vue'

const props = defineProps<{
  workMinutes: number
  workSeconds: number
  restMinutes: number
  restSeconds: number
  rounds: number
}>()

const emit = defineEmits<{
  'update:workMinutes': [value: number]
  'update:workSeconds': [value: number]
  'update:restMinutes': [value: number]
  'update:restSeconds': [value: number]
  'update:rounds': [value: number]
}>()

const adjustWorkDuration = (delta: number) => {
  let totalSec = props.workMinutes * 60 + props.workSeconds + delta
  totalSec = Math.min(99 * 60 + 59, Math.max(0, totalSec))
  emit('update:workMinutes', Math.floor(totalSec / 60))
  emit('update:workSeconds', totalSec % 60)
}

const adjustRestDuration = (delta: number) => {
  let totalSec = props.restMinutes * 60 + props.restSeconds + delta
  totalSec = Math.min(99 * 60 + 59, Math.max(0, totalSec))
  emit('update:restMinutes', Math.floor(totalSec / 60))
  emit('update:restSeconds', totalSec % 60)
}
</script>

<template>
  <Card class="p-4 space-y-5">
    <DurationInput
      label="WORK DURATION"
      :minutes="workMinutes"
      :seconds="workSeconds"
      :step="5"
      size="sm"
      @update:minutes="$emit('update:workMinutes', $event)"
      @update:seconds="$emit('update:workSeconds', $event)"
      @adjust="adjustWorkDuration"
    />

    <DurationInput
      label="REST DURATION"
      :minutes="restMinutes"
      :seconds="restSeconds"
      :step="5"
      size="sm"
      @update:minutes="$emit('update:restMinutes', $event)"
      @update:seconds="$emit('update:restSeconds', $event)"
      @adjust="adjustRestDuration"
    />

    <NumberInput
      label="ROUNDS"
      :modelValue="rounds"
      :min="1"
      :max="99"
      :step="1"
      @update:modelValue="$emit('update:rounds', $event)"
    />
  </Card>
</template>
