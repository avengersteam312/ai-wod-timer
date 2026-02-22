<script setup lang="ts">
import { useRoute, useRouter } from 'vue-router'
import { Timer, GalleryVerticalEnd, History } from 'lucide-vue-next'
import { useWorkoutStore } from '@/stores/workoutStore'
import { useTimerStore } from '@/stores/timerStore'

const route = useRoute()
const router = useRouter()
const workoutStore = useWorkoutStore()
const timerStore = useTimerStore()

interface NavItem {
  name: string
  path: string
  icon: typeof Timer
  label: string
}

const navItems: NavItem[] = [
  { name: 'manual', path: '/manual', icon: Timer, label: 'Manual' },
  { name: 'timer', path: '/', icon: GalleryVerticalEnd, label: 'Dashboard' },
  { name: 'history', path: '/history', icon: History, label: 'History' },
]

const isActive = (item: NavItem): boolean => {
  return route.path === item.path || route.name === item.name
}

const navigate = (path: string) => {
  // Clear workout state when switching between timer views
  if (path === '/' || path === '/manual') {
    workoutStore.clearWorkout()
    timerStore.reset()
  }
  router.push(path)
}
</script>

<template>
  <nav class="fixed bottom-0 left-0 right-0 z-50 bg-card border-t border-border safe-area-pb safe-area-pl safe-area-pr">
    <div class="max-w-md mx-auto flex items-center justify-around">
      <button
        v-for="item in navItems"
        :key="item.name"
        @click="navigate(item.path)"
        class="flex flex-col items-center justify-center py-2 px-4 min-w-[72px] transition-colors"
        :class="[
          isActive(item)
            ? 'text-primary'
            : 'text-muted-foreground hover:text-foreground'
        ]"
        :aria-label="item.label"
        :aria-current="isActive(item) ? 'page' : undefined"
      >
        <component
          :is="item.icon"
          class="h-6 w-6 mb-1"
          :class="{ 'text-primary': isActive(item) }"
        />
        <span
          class="text-xs font-medium"
          :class="{ 'text-primary': isActive(item) }"
        >
          {{ item.label }}
        </span>
      </button>
    </div>
  </nav>
</template>
