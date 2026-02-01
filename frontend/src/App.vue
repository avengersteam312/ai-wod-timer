<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue'
import { RouterView, useRouter } from 'vue-router'
import { App } from '@capacitor/app'
import { Capacitor } from '@capacitor/core'

const router = useRouter()
const showExitConfirm = ref(false)
let backButtonListener: { remove: () => Promise<void> } | null = null

onMounted(async () => {
  if (Capacitor.isNativePlatform() && Capacitor.getPlatform() === 'android') {
    backButtonListener = await App.addListener('backButton', ({ canGoBack }) => {
      if (canGoBack) {
        router.back()
      } else {
        // On root route, show exit confirmation
        showExitConfirm.value = true
      }
    })
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
  App.exitApp()
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
