<script setup lang="ts">
import { computed } from 'vue'
import Card from '@/components/ui/Card.vue'
import SecondsInput from '../inputs/SecondsInput.vue'
import NumberInput from '../inputs/NumberInput.vue'
import { formatSeconds } from '../composables/useInputHandlers'

const props = defineProps<{
  workSeconds: number
  restSeconds: number
  rounds: number
}>()

const emit = defineEmits<{
  'update:workSeconds': [value: number]
  'update:restSeconds': [value: number]
  'update:rounds': [value: number]
}>()

const totalTime = computed(() => {
  return formatSeconds(props.workSeconds * props.rounds + props.restSeconds * (props.rounds - 1))
})
</script>

<template>
  <Card class="p-4 space-y-5">
    <SecondsInput
      label="WORK (seconds)"
      :modelValue="workSeconds"
      :min="5"
      :max="120"
      :step="5"
      @update:modelValue="$emit('update:workSeconds', $event)"
    />

    <SecondsInput
      label="REST (seconds)"
      :modelValue="restSeconds"
      :min="5"
      :max="120"
      :step="5"
      @update:modelValue="$emit('update:restSeconds', $event)"
    />

    <NumberInput
      label="ROUNDS"
      :modelValue="rounds"
      :min="1"
      :max="99"
      :step="1"
      @update:modelValue="$emit('update:rounds', $event)"
    />

    <p class="text-xs text-muted-foreground text-center pt-2">
      Total: {{ totalTime }}
    </p>
  </Card>
</template>
