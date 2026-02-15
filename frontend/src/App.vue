<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue'
import { RouterView, useRouter } from 'vue-router'
import { useAudio } from '@/composables/useAudio'

const router = useRouter()
const { unlockAudio } = useAudio()
const showExitConfirm = ref(false)

// Unlock audio on first user interaction
const handleFirstInteraction = () => {
  unlockAudio()
  document.removeEventListener('click', handleFirstInteraction)
  document.removeEventListener('touchstart', handleFirstInteraction)
}

onMounted(() => {
  document.addEventListener('click', handleFirstInteraction, { once: true })
  document.addEventListener('touchstart', handleFirstInteraction, { once: true })
})
let backButtonListener: { remove: () => Promise<void> } | null = null
let CapacitorApp: typeof import('@capacitor/app').App | null = null

onMounted(async () => {
  if (!__CAPACITOR_ENABLED__) return

  try {
    const { Capacitor } = await import('@capacitor/core')
    if (Capacitor.isNativePlatform() && Capacitor.getPlatform() === 'android') {
      const { App } = await import('@capacitor/app')
      CapacitorApp = App
      backButtonListener = await App.addListener('backButton', ({ canGoBack }) => {
        if (canGoBack) {
          router.back()
        } else {
          showExitConfirm.value = true
        }
      })
    }
  } catch {
    // Capacitor not available, skip
  }
})

onUnmounted(async () => {
  if (backButtonListener) {
    await backButtonListener.remove()
    backButtonListener = null
  }
})

function confirmExit() {
  showExitConfirm.value = false
  CapacitorApp?.exitApp()
}

function cancelExit() {
  showExitConfirm.value = false
}
</script>

<template>
  <RouterView />

  <!-- Exit Confirmation Dialog -->
  <Teleport to="body">
    <div
      v-if="showExitConfirm"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      @click.self="cancelExit"
    >
      <div class="mx-4 w-full max-w-sm rounded-lg bg-zinc-800 p-6 shadow-xl">
        <h2 class="mb-4 text-lg font-semibold text-white">Exit App</h2>
        <p class="mb-6 text-zinc-300">Are you sure you want to exit?</p>
        <div class="flex justify-end gap-3">
          <button
            class="rounded-lg px-4 py-2 text-zinc-300 hover:bg-zinc-700"
            @click="cancelExit"
          >
            Cancel
          </button>
          <button
            class="rounded-lg bg-red-600 px-4 py-2 text-white hover:bg-red-700"
            @click="confirmExit"
          >
            Exit
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
