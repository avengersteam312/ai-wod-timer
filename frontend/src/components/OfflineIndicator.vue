<script setup lang="ts">
import { WifiOff, RefreshCw, AlertCircle, CloudOff } from 'lucide-vue-next'
import { useOfflineStatus } from '@/composables/useOfflineStatus'

const {
  isOffline,
  isSyncing,
  hasSyncError,
  statusMessage,
  statusVariant,
  hasPending
} = useOfflineStatus()
</script>

<template>
  <!-- Offline/Sync Status Indicator -->
  <Transition
    enter-active-class="transition ease-out duration-200"
    enter-from-class="opacity-0 scale-95"
    enter-to-class="opacity-100 scale-100"
    leave-active-class="transition ease-in duration-150"
    leave-from-class="opacity-100 scale-100"
    leave-to-class="opacity-0 scale-95"
  >
    <div
      v-if="statusVariant"
      class="flex items-center gap-1.5 px-2 py-1 rounded-full text-xs font-medium"
      :class="{
        'bg-amber-500/20 text-amber-500': statusVariant === 'offline',
        'bg-blue-500/20 text-blue-500': statusVariant === 'syncing',
        'bg-destructive/20 text-destructive': statusVariant === 'error',
        'bg-muted text-muted-foreground': statusVariant === 'pending'
      }"
      role="status"
      :aria-label="statusMessage ?? undefined"
    >
      <!-- Offline Icon -->
      <WifiOff
        v-if="isOffline"
        class="h-3.5 w-3.5"
      />
      <!-- Syncing Icon (animated) -->
      <RefreshCw
        v-else-if="isSyncing"
        class="h-3.5 w-3.5 animate-spin"
      />
      <!-- Error Icon -->
      <AlertCircle
        v-else-if="hasSyncError"
        class="h-3.5 w-3.5"
      />
      <!-- Pending Icon -->
      <CloudOff
        v-else-if="hasPending"
        class="h-3.5 w-3.5"
      />

      <span>{{ statusMessage }}</span>
    </div>
  </Transition>
</template>
