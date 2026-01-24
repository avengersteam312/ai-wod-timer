<script setup lang="ts">
import Card from '@/components/ui/Card.vue'
import NumberInput from '../inputs/NumberInput.vue'

defineProps<{
  rounds: number
}>()

defineEmits<{
  'update:rounds': [value: number]
}>()
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

    <p class="text-xs text-muted-foreground text-center pt-2">
      Work until done, then rest for the same duration
    </p>
  </Card>
</template>
