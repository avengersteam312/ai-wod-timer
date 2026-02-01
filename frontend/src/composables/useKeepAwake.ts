/**
 * Keep Awake Composable
 *
 * Provides screen wake lock functions for native mobile platforms.
 * Keeps the screen on during active workouts and allows sleep when paused/stopped.
 * Gracefully degrades to no-op on web platforms.
 */
import { Capacitor } from '@capacitor/core'
import { KeepAwake } from '@capacitor-community/keep-awake'
import { ref } from 'vue'

/**
 * Check if running on a native platform (iOS/Android)
 */
function isNativePlatform(): boolean {
  return Capacitor.isNativePlatform()
}

export function useKeepAwake() {
  const isKeptAwake = ref(false)

  /**
   * Keep the screen awake (prevent display from sleeping)
   * Call when timer starts playing
   */
  const keepAwake = async (): Promise<void> => {
    if (!isNativePlatform()) {
      isKeptAwake.value = true
      return
    }
    await KeepAwake.keepAwake()
    isKeptAwake.value = true
  }

  /**
   * Allow the screen to sleep normally
   * Call when timer is paused, reset, or completed
   */
  const allowSleep = async (): Promise<void> => {
    if (!isNativePlatform()) {
      isKeptAwake.value = false
      return
    }
    await KeepAwake.allowSleep()
    isKeptAwake.value = false
  }

  /**
   * Check if keep awake is currently supported
   */
  const isSupported = async (): Promise<boolean> => {
    if (!isNativePlatform()) return false
    const result = await KeepAwake.isSupported()
    return result.isSupported
  }

  /**
   * Check current keep awake status from the native side
   */
  const isCurrentlyKeptAwake = async (): Promise<boolean> => {
    if (!isNativePlatform()) return isKeptAwake.value
    const result = await KeepAwake.isKeptAwake()
    return result.isKeptAwake
  }

  return {
    isKeptAwake,
    keepAwake,
    allowSleep,
    isSupported,
    isCurrentlyKeptAwake,
    isNativePlatform,
  }
}
