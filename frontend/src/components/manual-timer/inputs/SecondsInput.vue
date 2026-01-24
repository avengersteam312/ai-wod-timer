<script setup lang="ts">
import { selectOnFocus, padSeconds } from '../composables/useInputHandlers'

const props = withDefaults(defineProps<{
  modelValue: number
  label?: string
  min?: number
  max?: number
  step?: number
}>(), {
  min: 5,
  max: 120,
  step: 5
})

const emit = defineEmits<{
  'update:modelValue': [value: number]
}>()

const adjust = (delta: number) => {
  const newValue = props.modelValue + delta
  if (newValue >= props.min && newValue <= props.max) {
    emit('update:modelValue', newValue)
  }
}

const onBlur = (e: Event) => {
  const val = parseInt((e.target as HTMLInputElement).value) || 0
  emit('update:modelValue', Math.min(props.max, Math.max(props.min, val)))
}
</script>

<template>
  <div class="space-y-2">
    <label v-if="label" class="text-[10px] font-semibold tracking-wider text-muted-foreground block">
      {{ label }}
    </label>
    <div class="flex items-center gap-3">
      <button
        @click="adjust(-step)"
        class="bg-surface-elevated rounded-lg p-2 text-muted-foreground hover:text-foreground"
        type="button"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4"/>
        </svg>
      </button>
      <div class="flex-1 bg-surface-elevated rounded-lg px-3 py-2 flex items-center justify-center">
        <input
          type="text"
          inputmode="numeric"
          :value="padSeconds(modelValue)"
          @blur="onBlur"
          @focus="selectOnFocus"
          maxlength="3"
          :aria-label="label"
          class="w-16 text-xl font-bold text-center bg-transparent outline-none"
        />
        <span class="text-xl font-bold text-muted-foreground">s</span>
      </div>
      <button
        @click="adjust(step)"
        class="bg-surface-elevated rounded-lg p-2 text-muted-foreground hover:text-foreground"
        type="button"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
      </button>
    </div>
  </div>
</template>
