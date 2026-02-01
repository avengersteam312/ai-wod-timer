/**
 * Keep Awake Composable
 *
 * Provides screen wake lock functions for native mobile platforms.
 * Keeps the screen on during active workouts and allows sleep when paused/stopped.
 * Gracefully degrades to no-op on web platforms.
 */
import { ref } from 'vue'

// Lazy-loaded Capacitor modules (only loaded on native)
let Capacitor: typeof import('@capacitor/core').Capacitor | null = null
let KeepAwake: typeof import('@capacitor-community/keep-awake').KeepAwake | null = null

/**
 * Check if running on a native platform (iOS/Android)
 */
async function isNativePlatform(): Promise<boolean> {
  try {
    if (!Capacitor) {
      const mod = await import('@capacitor/core')
      Capacitor = mod.Capacitor
    }
    return Capacitor.isNativePlatform()
  } catch {
    return false
  }
}

async function loadKeepAwake() {
  if (!KeepAwake) {
    try {
      const mod = await import('@capacitor-community/keep-awake')
      KeepAwake = mod.KeepAwake
    } catch {
      KeepAwake = null
    }
  }
  return KeepAwake
}

export function useKeepAwake() {
  const isKeptAwake = ref(false)

  /**
   * Keep the screen awake (prevent display from sleeping)
   * Call when timer starts playing
   */
  const keepAwake = async (): Promise<void> => {
    if (!(await isNativePlatform())) {
      isKeptAwake.value = true
      return
    }
    const ka = await loadKeepAwake()
    if (ka) {
      await ka.keepAwake()
    }
    isKeptAwake.value = true
  }

  /**
   * Allow the screen to sleep normally
   * Call when timer is paused, reset, or completed
   */
  const allowSleep = async (): Promise<void> => {
    if (!(await isNativePlatform())) {
      isKeptAwake.value = false
      return
    }
    const ka = await loadKeepAwake()
    if (ka) {
      await ka.allowSleep()
    }
    isKeptAwake.value = false
  }

  /**
   * Check if keep awake is currently supported
   */
  const isSupported = async (): Promise<boolean> => {
    if (!(await isNativePlatform())) return false
    const ka = await loadKeepAwake()
    if (!ka) return false
    const result = await ka.isSupported()
    return result.isSupported
  }

  /**
   * Check current keep awake status from the native side
   */
  const isCurrentlyKeptAwake = async (): Promise<boolean> => {
    if (!(await isNativePlatform())) return isKeptAwake.value
    const ka = await loadKeepAwake()
    if (!ka) return isKeptAwake.value
    const result = await ka.isKeptAwake()
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
