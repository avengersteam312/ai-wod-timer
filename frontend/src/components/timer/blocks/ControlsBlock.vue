<script setup lang="ts">
import TimerControls from '@/components/timer/TimerControls.vue'

const emit = defineEmits<{
  done: []
}>()
</script>

<template>
  <div class="py-2">
    <TimerControls @done="emit('done')" />
  </div>
</template>
