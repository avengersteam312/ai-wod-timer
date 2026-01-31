<script setup lang="ts">
import { CloudOff, Check } from 'lucide-vue-next'

defineProps<{
  show: boolean
  message?: string
}>()
</script>

<template>
  <Transition
    enter-active-class="transition ease-out duration-200"
    enter-from-class="opacity-0 -translate-y-2"
    enter-to-class="opacity-100 translate-y-0"
    leave-active-class="transition ease-in duration-150"
    leave-from-class="opacity-100 translate-y-0"
    leave-to-class="opacity-0 -translate-y-2"
  >
    <div
      v-if="show"
      class="mx-4 mb-2 px-4 py-2 bg-amber-500/20 border border-amber-500/30 text-amber-500 rounded-lg text-sm flex items-center gap-2"
      role="status"
      aria-live="polite"
    >
      <CloudOff class="h-4 w-4 shrink-0" />
      <span class="flex-1">{{ message ?? 'Saved locally. Will sync when online.' }}</span>
      <Check class="h-4 w-4 shrink-0" />
    </div>
  </Transition>
</template>
