/**
 * Capacitor Storage Service
 *
 * Provides a unified storage API that works across web and native platforms.
 * Uses Capacitor Preferences plugin on native devices for persistent storage,
 * and falls back to localStorage on web.
 */

// Lazy-loaded Capacitor modules (only on native builds)
let Preferences: typeof import('@capacitor/preferences').Preferences | null = null

async function isNativePlatform(): Promise<boolean> {
  if (!__CAPACITOR_ENABLED__) return false

  try {
    const { Capacitor } = await import('@capacitor/core')
    return Capacitor.isNativePlatform()
  } catch {
    return false
  }
}

async function loadPreferences() {
  if (!__CAPACITOR_ENABLED__) return null

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
 */
export async function get(key: string): Promise<string | null> {
  if (__CAPACITOR_ENABLED__ && (await isNativePlatform())) {
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
 */
export async function set(key: string, value: string): Promise<void> {
  if (__CAPACITOR_ENABLED__ && (await isNativePlatform())) {
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
 */
export async function remove(key: string): Promise<void> {
  if (__CAPACITOR_ENABLED__ && (await isNativePlatform())) {
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
  if (__CAPACITOR_ENABLED__ && (await isNativePlatform())) {
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
 */
export async function keys(): Promise<string[]> {
  if (__CAPACITOR_ENABLED__ && (await isNativePlatform())) {
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
