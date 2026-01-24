<script setup lang="ts">
import { computed } from 'vue'
import Card from '@/components/ui/Card.vue'
import NumberInput from '../inputs/NumberInput.vue'

const props = defineProps<{
  rounds: number
  intervalMinutes: number
}>()

const emit = defineEmits<{
  'update:rounds': [value: number]
  'update:intervalMinutes': [value: number]
}>()

const totalMinutes = computed(() => props.rounds * props.intervalMinutes)
</script>

<template>
  <Card class="p-4 space-y-5">
    <NumberInput
      label="ROUNDS"
      :modelValue="rounds"
      :min="1"
      :max="99"
      :step="1"
      @update:modelValue="$emit('update:rounds', $event)"
    />

    <NumberInput
      label="EVERY X MINUTES"
      :modelValue="intervalMinutes"
      :min="1"
      :max="10"
      :step="1"
      suffix="min"
      @update:modelValue="$emit('update:intervalMinutes', $event)"
    />

    <p class="text-xs text-muted-foreground text-center pt-2">
      {{ rounds }} rounds × {{ intervalMinutes }} min = {{ totalMinutes }} min total
    </p>
  </Card>
</template>
