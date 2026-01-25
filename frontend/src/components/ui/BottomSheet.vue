<script setup lang="ts">
import { watch, computed, onUnmounted } from 'vue'

interface Props {
  open: boolean
  title?: string
  size?: 'default' | 'large' | 'full'
  showHandle?: boolean
}

const props = withDefaults(defineProps<Props>(), {
  size: 'default',
  showHandle: true
})

defineEmits<{
  'update:open': [value: boolean]
}>()

const heightClass = computed(() => {
  switch (props.size) {
    case 'full':
      return 'h-[calc(100vh-23.5rem)]'
    case 'large':
      return 'min-h-[50vh] max-h-[85vh]'
    default:
      return 'max-h-[85vh]'
  }
})

// Prevent body scroll when open
watch(() => props.open, (isOpen) => {
  document.body.style.overflow = isOpen ? 'hidden' : ''
})

// Cleanup on unmount
onUnmounted(() => {
  document.body.style.overflow = ''
})
</script>

<template>
  <Teleport to="body">
    <Transition name="sheet">
      <div
        v-if="open"
        class="fixed bottom-0 left-0 right-0 z-50 flex justify-center"
      >
        <div :class="['w-full max-w-md bg-surface rounded-t-2xl flex flex-col', heightClass]">
        <!-- Handle bar -->
        <div v-if="showHandle" class="flex justify-center pt-3 pb-2">
          <div class="w-10 h-1 bg-muted-foreground/30 rounded-full" />
        </div>

        <!-- Header -->
        <div v-if="title" class="px-4 pb-3 border-b border-border">
          <h3 class="text-lg font-semibold text-foreground">{{ title }}</h3>
        </div>

        <!-- Content -->
        <div class="flex-1 overflow-y-auto p-4">
          <slot />
        </div>

        <!-- Actions -->
        <div v-if="$slots.actions" class="p-4 border-t border-border">
          <slot name="actions" />
        </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.sheet-enter-active,
.sheet-leave-active {
  transition: transform 0.3s ease;
}

.sheet-enter-from,
.sheet-leave-to {
  transform: translateY(100%);
}
</style>
