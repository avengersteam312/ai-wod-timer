/**
 * Capacitor Storage Service
 *
 * Provides a unified storage API that works across web and native platforms.
 * Uses Capacitor Preferences plugin on native devices for persistent storage,
 * and falls back to localStorage on web.
 */

// Lazy-loaded Capacitor modules
let Capacitor: typeof import('@capacitor/core').Capacitor | null = null
let Preferences: typeof import('@capacitor/preferences').Preferences | null = null

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

async function loadPreferences() {
  if (!Preferences) {
    try {
      const mod = await import('@capacitor/preferences')
      Preferences = mod.Preferences
    } catch {
      Preferences = null
    }
  }
  return Preferences
}

/**
 * Get a value from storage
 *
 * @param key - The key to retrieve
 * @returns The stored value, or null if not found
 */
export async function get(key: string): Promise<string | null> {
  if (await isNativePlatform()) {
    const prefs = await loadPreferences()
    if (prefs) {
      const { value } = await prefs.get({ key })
      return value
    }
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
  if (await isNativePlatform()) {
    const prefs = await loadPreferences()
    if (prefs) {
      await prefs.set({ key, value })
      return
    }
  }
  localStorage.setItem(key, value)
}

/**
 * Remove a value from storage
 *
 * @param key - The key to remove
 */
export async function remove(key: string): Promise<void> {
  if (await isNativePlatform()) {
    const prefs = await loadPreferences()
    if (prefs) {
      await prefs.remove({ key })
      return
    }
  }
  localStorage.removeItem(key)
}

/**
 * Clear all values from storage
 */
export async function clear(): Promise<void> {
  if (await isNativePlatform()) {
    const prefs = await loadPreferences()
    if (prefs) {
      await prefs.clear()
      return
    }
  }
  localStorage.clear()
}

/**
 * Get all keys from storage
 *
 * @returns Array of all stored keys
 */
export async function keys(): Promise<string[]> {
  if (await isNativePlatform()) {
    const prefs = await loadPreferences()
    if (prefs) {
      const { keys: storedKeys } = await prefs.keys()
      return storedKeys
    }
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
