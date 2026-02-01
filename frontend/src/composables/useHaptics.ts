/**
 * Haptics Composable
 *
 * Provides haptic feedback functions for native mobile platforms.
 * Gracefully degrades to no-op on web platforms.
 */

// Lazy-loaded Capacitor modules
let Capacitor: typeof import('@capacitor/core').Capacitor | null = null
let Haptics: typeof import('@capacitor/haptics').Haptics | null = null
let ImpactStyle: typeof import('@capacitor/haptics').ImpactStyle | null = null
let NotificationType: typeof import('@capacitor/haptics').NotificationType | null = null

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

async function loadHaptics() {
  if (!Haptics) {
    try {
      const mod = await import('@capacitor/haptics')
      Haptics = mod.Haptics
      ImpactStyle = mod.ImpactStyle
      NotificationType = mod.NotificationType
    } catch {
      Haptics = null
    }
  }
  return { Haptics, ImpactStyle, NotificationType }
}

export function useHaptics() {
  /**
   * Light impact haptic - for subtle UI interactions
   */
  const vibrateLight = async (): Promise<void> => {
    if (!(await isNativePlatform())) return
    const { Haptics: H, ImpactStyle: IS } = await loadHaptics()
    if (H && IS) await H.impact({ style: IS.Light })
  }

  /**
   * Medium impact haptic - for standard button presses
   */
  const vibrateMedium = async (): Promise<void> => {
    if (!(await isNativePlatform())) return
    const { Haptics: H, ImpactStyle: IS } = await loadHaptics()
    if (H && IS) await H.impact({ style: IS.Medium })
  }

  /**
   * Heavy impact haptic - for significant actions
   */
  const vibrateHeavy = async (): Promise<void> => {
    if (!(await isNativePlatform())) return
    const { Haptics: H, ImpactStyle: IS } = await loadHaptics()
    if (H && IS) await H.impact({ style: IS.Heavy })
  }

  /**
   * Success notification haptic - for successful completions
   */
  const vibrateSuccess = async (): Promise<void> => {
    if (!(await isNativePlatform())) return
    const { Haptics: H, NotificationType: NT } = await loadHaptics()
    if (H && NT) await H.notification({ type: NT.Success })
  }

  /**
   * Warning notification haptic - for warnings/alerts
   */
  const vibrateWarning = async (): Promise<void> => {
    if (!(await isNativePlatform())) return
    const { Haptics: H, NotificationType: NT } = await loadHaptics()
    if (H && NT) await H.notification({ type: NT.Warning })
  }

  /**
   * Error notification haptic - for error states
   */
  const vibrateError = async (): Promise<void> => {
    if (!(await isNativePlatform())) return
    const { Haptics: H, NotificationType: NT } = await loadHaptics()
    if (H && NT) await H.notification({ type: NT.Error })
  }

  /**
   * Selection changed haptic - for picker/selection UI elements
   */
  const vibrateSelection = async (): Promise<void> => {
    if (!(await isNativePlatform())) return
    const { Haptics: H } = await loadHaptics()
    if (H) await H.selectionChanged()
  }

  /**
   * Start selection haptic sequence
   */
  const selectionStart = async (): Promise<void> => {
    if (!(await isNativePlatform())) return
    const { Haptics: H } = await loadHaptics()
    if (H) await H.selectionStart()
  }

  /**
   * End selection haptic sequence
   */
  const selectionEnd = async (): Promise<void> => {
    if (!(await isNativePlatform())) return
    const { Haptics: H } = await loadHaptics()
    if (H) await H.selectionEnd()
  }

  return {
    vibrateLight,
    vibrateMedium,
    vibrateHeavy,
    vibrateSuccess,
    vibrateWarning,
    vibrateError,
    vibrateSelection,
    selectionStart,
    selectionEnd,
    isNativePlatform,
  }
}
