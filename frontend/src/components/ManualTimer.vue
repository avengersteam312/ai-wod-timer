<script setup lang="ts">
// Forward all functionality from the modular version
import ManualTimerSetup from './manual-timer/ManualTimerSetup.vue'

defineEmits<{
  switchToAI: []
}>()
</script>

<template>
  <ManualTimerSetup @switch-to-a-i="$emit('switchToAI')" />
</template>
