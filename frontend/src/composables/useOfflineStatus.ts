/**
 * useOfflineStatus Composable
 *
 * Provides reactive online/offline and sync status for the UI.
 * Integrates with syncService to show appropriate indicators.
 */
import { ref, onMounted, onUnmounted, computed } from 'vue'
import {
  initSyncService,
  cleanupSyncService,
  onSyncStatusChange,
  isOnline as checkOnline,
  hasPendingSync,
  type SyncStatus
} from '@/services/syncService'

/**
 * Check if the browser is currently online
 */
export function isOnline(): boolean {
  return typeof navigator !== 'undefined' ? navigator.onLine : true
}

/**
 * Composable for managing offline/sync status in UI components
 */
export function useOfflineStatus() {
  const online = ref(isOnline())
  const syncStatus = ref<SyncStatus>('idle')
  const hasPending = ref(false)

  // Derived states for UI
  const isOffline = computed(() => !online.value)
  const isSyncing = computed(() => syncStatus.value === 'syncing')
  const hasSyncError = computed(() => syncStatus.value === 'error')

  // Status message for display
  const statusMessage = computed(() => {
    if (!online.value) return 'Offline'
    if (syncStatus.value === 'syncing') return 'Syncing...'
    if (syncStatus.value === 'error') return 'Sync failed'
    if (hasPending.value) return 'Pending changes'
    return null
  })

  // Status variant for styling
  const statusVariant = computed((): 'offline' | 'syncing' | 'error' | 'pending' | null => {
    if (!online.value) return 'offline'
    if (syncStatus.value === 'syncing') return 'syncing'
    if (syncStatus.value === 'error') return 'error'
    if (hasPending.value) return 'pending'
    return null
  })

  // Check pending sync status periodically
  const checkPendingStatus = async () => {
    hasPending.value = await hasPendingSync()
  }

  // Handle sync status changes from syncService
  const handleSyncStatusChange = (status: SyncStatus) => {
    syncStatus.value = status
    online.value = status !== 'offline'

    // After sync completes, check if there are still pending items
    if (status === 'idle' || status === 'error') {
      checkPendingStatus()
    }
  }

  // Update online status directly from browser events
  const handleOnline = () => {
    online.value = true
  }

  const handleOffline = () => {
    online.value = false
    syncStatus.value = 'offline'
  }

  onMounted(() => {
    // Initialize sync service (sets up event listeners)
    initSyncService()

    // Subscribe to sync status changes
    onSyncStatusChange(handleSyncStatusChange)

    // Add our own listeners for immediate UI updates
    window.addEventListener('online', handleOnline)
    window.addEventListener('offline', handleOffline)

    // Check initial online and pending status
    online.value = checkOnline()
    checkPendingStatus()
  })

  onUnmounted(() => {
    // Cleanup sync service
    cleanupSyncService()

    // Remove our listeners
    window.removeEventListener('online', handleOnline)
    window.removeEventListener('offline', handleOffline)
  })

  return {
    // State
    online,
    syncStatus,
    hasPending,

    // Computed
    isOffline,
    isSyncing,
    hasSyncError,
    statusMessage,
    statusVariant,

    // Methods
    checkPendingStatus
  }
}
