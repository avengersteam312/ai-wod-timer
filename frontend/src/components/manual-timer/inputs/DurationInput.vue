<script setup lang="ts">
import { computed } from 'vue'
import { selectOnFocus, padSeconds } from '../composables/useInputHandlers'

const props = withDefaults(defineProps<{
  minutes: number
  seconds: number
  label?: string
  step?: number
  size?: 'sm' | 'lg'
}>(), {
  step: 60,
  size: 'lg'
})

const emit = defineEmits<{
  'update:minutes': [value: number]
  'update:seconds': [value: number]
  adjust: [delta: number]
}>()

const sizeClasses = computed(() => ({
  container: props.size === 'lg' ? 'px-4 py-3' : 'px-3 py-2',
  text: props.size === 'lg' ? 'text-4xl' : 'text-xl',
  input: props.size === 'lg' ? 'w-16' : 'w-12',
  button: props.size === 'lg' ? 'p-3' : 'p-2',
  icon: props.size === 'lg' ? 'w-5 h-5' : 'w-4 h-4'
}))

const onMinutesBlur = (e: Event) => {
  const val = parseInt((e.target as HTMLInputElement).value) || 0
  emit('update:minutes', Math.min(99, Math.max(0, val)))
}

const onSecondsBlur = (e: Event) => {
  const val = parseInt((e.target as HTMLInputElement).value) || 0
  emit('update:seconds', Math.min(59, Math.max(0, val)))
}
</script>

<template>
  <div class="space-y-2">
    <label v-if="label" class="text-[10px] font-semibold tracking-wider text-muted-foreground block">
      {{ label }}
    </label>
    <div class="flex items-center gap-3">
      <button
        @click="$emit('adjust', -step)"
        :class="['bg-surface-elevated rounded-lg text-muted-foreground hover:text-foreground', sizeClasses.button]"
        type="button"
      >
        <svg :class="sizeClasses.icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4"/>
        </svg>
      </button>
      <div :class="['flex-1 bg-surface-elevated rounded-lg flex items-center justify-center gap-1', sizeClasses.container]">
        <input
          type="text"
          inputmode="numeric"
          :value="minutes"
          @blur="onMinutesBlur"
          @focus="selectOnFocus"
          maxlength="2"
          aria-label="Minutes"
          :class="[sizeClasses.text, sizeClasses.input, 'font-bold text-center bg-transparent outline-none']"
        />
        <span :class="[sizeClasses.text, 'font-bold']">:</span>
        <input
          type="text"
          inputmode="numeric"
          :value="padSeconds(seconds)"
          @blur="onSecondsBlur"
          @focus="selectOnFocus"
          maxlength="2"
          aria-label="Seconds"
          :class="[sizeClasses.text, sizeClasses.input, 'font-bold text-center bg-transparent outline-none']"
        />
      </div>
      <button
        @click="$emit('adjust', step)"
        :class="['bg-surface-elevated rounded-lg text-muted-foreground hover:text-foreground', sizeClasses.button]"
        type="button"
      >
        <svg :class="sizeClasses.icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
      </button>
    </div>
  </div>
</template>
