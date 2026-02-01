/**
 * Platform Detection Utility
 *
 * Provides functions to detect the current platform (iOS, Android, Web)
 * for conditional logic in the application.
 */
import { Capacitor } from '@capacitor/core'

/**
 * Check if running on a native platform (iOS or Android)
 */
export function isNative(): boolean {
  return Capacitor.isNativePlatform()
}

/**
 * Check if running on iOS
 */
export function isIOS(): boolean {
  return Capacitor.getPlatform() === 'ios'
}

/**
 * Check if running on Android
 */
export function isAndroid(): boolean {
  return Capacitor.getPlatform() === 'android'
}

/**
 * Check if running on web (not native)
 */
export function isWeb(): boolean {
  return !Capacitor.isNativePlatform()
}

/**
 * Get the current platform name
 * @returns 'ios' | 'android' | 'web'
 */
export function getPlatform(): 'ios' | 'android' | 'web' {
  return Capacitor.getPlatform() as 'ios' | 'android' | 'web'
}

/**
 * Platform constant object for convenient imports
 * This can be used for reactive usage in Vue components
 */
export const platform = {
  isNative: isNative(),
  isIOS: isIOS(),
  isAndroid: isAndroid(),
  isWeb: isWeb(),
  name: getPlatform(),
} as const

export default platform
