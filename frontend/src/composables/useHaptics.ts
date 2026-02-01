/**
 * Haptics Composable
 *
 * Provides haptic feedback functions for native mobile platforms.
 * Gracefully degrades to no-op on web platforms.
 */
import { Capacitor } from '@capacitor/core'
import { Haptics, ImpactStyle, NotificationType } from '@capacitor/haptics'

/**
 * Check if running on a native platform (iOS/Android)
 */
function isNativePlatform(): boolean {
  return Capacitor.isNativePlatform()
}

export function useHaptics() {
  /**
   * Light impact haptic - for subtle UI interactions
   */
  const vibrateLight = async (): Promise<void> => {
    if (!isNativePlatform()) return
    await Haptics.impact({ style: ImpactStyle.Light })
  }

  /**
   * Medium impact haptic - for standard button presses
   */
  const vibrateMedium = async (): Promise<void> => {
    if (!isNativePlatform()) return
    await Haptics.impact({ style: ImpactStyle.Medium })
  }

  /**
   * Heavy impact haptic - for significant actions
   */
  const vibrateHeavy = async (): Promise<void> => {
    if (!isNativePlatform()) return
    await Haptics.impact({ style: ImpactStyle.Heavy })
  }

  /**
   * Success notification haptic - for successful completions
   */
  const vibrateSuccess = async (): Promise<void> => {
    if (!isNativePlatform()) return
    await Haptics.notification({ type: NotificationType.Success })
  }

  /**
   * Warning notification haptic - for warnings/alerts
   */
  const vibrateWarning = async (): Promise<void> => {
    if (!isNativePlatform()) return
    await Haptics.notification({ type: NotificationType.Warning })
  }

  /**
   * Error notification haptic - for error states
   */
  const vibrateError = async (): Promise<void> => {
    if (!isNativePlatform()) return
    await Haptics.notification({ type: NotificationType.Error })
  }

  /**
   * Selection changed haptic - for picker/selection UI elements
   */
  const vibrateSelection = async (): Promise<void> => {
    if (!isNativePlatform()) return
    await Haptics.selectionChanged()
  }

  /**
   * Start selection haptic sequence
   */
  const selectionStart = async (): Promise<void> => {
    if (!isNativePlatform()) return
    await Haptics.selectionStart()
  }

  /**
   * End selection haptic sequence
   */
  const selectionEnd = async (): Promise<void> => {
    if (!isNativePlatform()) return
    await Haptics.selectionEnd()
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
