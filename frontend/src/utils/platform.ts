/**
 * Platform Detection Utility
 *
 * Provides functions to detect the current platform (iOS, Android, Web)
 * for conditional logic in the application.
 * Uses dynamic imports to avoid build errors on web deployments.
 */

// Lazy-loaded Capacitor module
let Capacitor: typeof import('@capacitor/core').Capacitor | null = null
let loaded = false

async function loadCapacitor() {
  if (!loaded) {
    try {
      const mod = await import('@capacitor/core')
      Capacitor = mod.Capacitor
    } catch {
      Capacitor = null
    }
    loaded = true
  }
  return Capacitor
}

/**
 * Check if running on a native platform (iOS or Android)
 */
export async function isNative(): Promise<boolean> {
  const cap = await loadCapacitor()
  return cap?.isNativePlatform() ?? false
}

/**
 * Check if running on iOS
 */
export async function isIOS(): Promise<boolean> {
  const cap = await loadCapacitor()
  return cap?.getPlatform() === 'ios'
}

/**
 * Check if running on Android
 */
export async function isAndroid(): Promise<boolean> {
  const cap = await loadCapacitor()
  return cap?.getPlatform() === 'android'
}

/**
 * Check if running on web (not native)
 */
export async function isWeb(): Promise<boolean> {
  const cap = await loadCapacitor()
  return !cap?.isNativePlatform()
}

/**
 * Get the current platform name
 * @returns 'ios' | 'android' | 'web'
 */
export async function getPlatform(): Promise<'ios' | 'android' | 'web'> {
  const cap = await loadCapacitor()
  return (cap?.getPlatform() as 'ios' | 'android' | 'web') ?? 'web'
}

/**
 * Synchronous platform check (returns false on web if Capacitor not loaded)
 * Use async versions for accurate detection
 */
export function isNativeSync(): boolean {
  return Capacitor?.isNativePlatform() ?? false
}

/**
 * Platform constant object for convenient imports
 * Note: These are evaluated at import time, use async functions for accuracy
 */
export const platform = {
  isNative,
  isIOS,
  isAndroid,
  isWeb,
  getPlatform,
  isNativeSync,
} as const

export default platform
