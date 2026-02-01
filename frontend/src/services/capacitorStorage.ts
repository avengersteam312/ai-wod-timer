/**
 * Capacitor Storage Service
 *
 * Provides a unified storage API that works across web and native platforms.
 * Uses Capacitor Preferences plugin on native devices for persistent storage,
 * and falls back to localStorage on web.
 */
import { Capacitor } from '@capacitor/core'
import { Preferences } from '@capacitor/preferences'

/**
 * Check if running on a native platform (iOS/Android)
 */
function isNativePlatform(): boolean {
  return Capacitor.isNativePlatform()
}

/**
 * Get a value from storage
 *
 * @param key - The key to retrieve
 * @returns The stored value, or null if not found
 */
export async function get(key: string): Promise<string | null> {
  if (isNativePlatform()) {
    const { value } = await Preferences.get({ key })
    return value
  }
  return localStorage.getItem(key)
}

/**
 * Set a value in storage
 *
 * @param key - The key to store
 * @param value - The value to store
 */
export async function set(key: string, value: string): Promise<void> {
  if (isNativePlatform()) {
    await Preferences.set({ key, value })
  } else {
    localStorage.setItem(key, value)
  }
}

/**
 * Remove a value from storage
 *
 * @param key - The key to remove
 */
export async function remove(key: string): Promise<void> {
  if (isNativePlatform()) {
    await Preferences.remove({ key })
  } else {
    localStorage.removeItem(key)
  }
}

/**
 * Clear all values from storage
 */
export async function clear(): Promise<void> {
  if (isNativePlatform()) {
    await Preferences.clear()
  } else {
    localStorage.clear()
  }
}

/**
 * Get all keys from storage
 *
 * @returns Array of all stored keys
 */
export async function keys(): Promise<string[]> {
  if (isNativePlatform()) {
    const { keys: storedKeys } = await Preferences.keys()
    return storedKeys
  }
  return Object.keys(localStorage)
}

/**
 * Capacitor Storage API object for convenient imports
 */
export const capacitorStorage = {
  get,
  set,
  remove,
  clear,
  keys,
  isNativePlatform,
}

export default capacitorStorage
