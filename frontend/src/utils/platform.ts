/**
 * Platform Detection Utility
 *
 * Provides functions to detect the current platform (iOS, Android, Web)
 * for conditional logic in the application.
 * Uses build-time flag to avoid loading Capacitor on web builds.
 */

/**
 * Check if running on a native platform (iOS or Android)
 */
export async function isNative(): Promise<boolean> {
  if (!__CAPACITOR_ENABLED__) return false

  try {
    const { Capacitor } = await import('@capacitor/core')
    return Capacitor.isNativePlatform()
  } catch {
    return false
  }
}

/**
 * Check if running on iOS
 */
export async function isIOS(): Promise<boolean> {
  if (!__CAPACITOR_ENABLED__) return false

  try {
    const { Capacitor } = await import('@capacitor/core')
    return Capacitor.getPlatform() === 'ios'
  } catch {
    return false
  }
}

/**
 * Check if running on Android
 */
export async function isAndroid(): Promise<boolean> {
  if (!__CAPACITOR_ENABLED__) return false

  try {
    const { Capacitor } = await import('@capacitor/core')
    return Capacitor.getPlatform() === 'android'
  } catch {
    return false
  }
}

/**
 * Check if running on web (not native)
 */
export async function isWeb(): Promise<boolean> {
  if (!__CAPACITOR_ENABLED__) return true

  try {
    const { Capacitor } = await import('@capacitor/core')
    return !Capacitor.isNativePlatform()
  } catch {
    return true
  }
}

/**
 * Get the current platform name
 * @returns 'ios' | 'android' | 'web'
 */
export async function getPlatform(): Promise<'ios' | 'android' | 'web'> {
  if (!__CAPACITOR_ENABLED__) return 'web'

  try {
    const { Capacitor } = await import('@capacitor/core')
    return Capacitor.getPlatform() as 'ios' | 'android' | 'web'
  } catch {
    return 'web'
  }
}

/**
 * Platform constant object for convenient imports
 */
export const platform = {
  isNative,
  isIOS,
  isAndroid,
  isWeb,
  getPlatform,
} as const

export default platform
