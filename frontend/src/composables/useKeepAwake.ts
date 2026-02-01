/**
 * Keep Awake Composable
 *
 * Provides screen wake lock functions for native mobile platforms.
 * Keeps the screen on during active workouts and allows sleep when paused/stopped.
 * Gracefully degrades to no-op on web platforms.
 */
import { ref } from 'vue'

// Lazy-loaded Capacitor modules (only on native builds)
let KeepAwake: typeof import('@capacitor-community/keep-awake').KeepAwake | null = null

async function loadKeepAwake() {
  if (!__CAPACITOR_ENABLED__) return null

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

async function isNativePlatform(): Promise<boolean> {
  if (!__CAPACITOR_ENABLED__) return false

  try {
    const { Capacitor } = await import('@capacitor/core')
    return Capacitor.isNativePlatform()
  } catch {
    return false
  }
}

export function useKeepAwake() {
  const isKeptAwake = ref(false)

  /**
   * Keep the screen awake (prevent display from sleeping)
   */
  const keepAwake = async (): Promise<void> => {
    if (!__CAPACITOR_ENABLED__) {
      isKeptAwake.value = true
      return
    }

    if (!(await isNativePlatform())) {
      isKeptAwake.value = true
      return
    }

    const ka = await loadKeepAwake()
    if (ka) await ka.keepAwake()
    isKeptAwake.value = true
  }

  /**
   * Allow the screen to sleep normally
   */
  const allowSleep = async (): Promise<void> => {
    if (!__CAPACITOR_ENABLED__) {
      isKeptAwake.value = false
      return
    }

    if (!(await isNativePlatform())) {
      isKeptAwake.value = false
      return
    }

    const ka = await loadKeepAwake()
    if (ka) await ka.allowSleep()
    isKeptAwake.value = false
  }

  /**
   * Check if keep awake is currently supported
   */
  const isSupported = async (): Promise<boolean> => {
    if (!__CAPACITOR_ENABLED__) return false
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
    if (!__CAPACITOR_ENABLED__) return isKeptAwake.value
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
