import type { Ref } from 'vue'

// Factory for creating blur handlers
export const createBlurHandler = (targetRef: Ref<number>, min: number, max: number) => (e: Event) => {
  const val = parseInt((e.target as HTMLInputElement).value) || 0
  targetRef.value = Math.min(max, Math.max(min, val))
}

// Factory for creating adjustment handlers
export const createAdjustHandler = (targetRef: Ref<number>, min: number, max: number) => (delta: number) => {
  const newValue = targetRef.value + delta
  if (newValue >= min && newValue <= max) {
    targetRef.value = newValue
  }
}

// Factory for duration adjustment (minutes:seconds pairs)
export const createDurationAdjustHandler = (minutesRef: Ref<number>, secondsRef: Ref<number>) => (delta: number) => {
  let totalSec = minutesRef.value * 60 + secondsRef.value + delta
  totalSec = Math.min(99 * 60 + 59, Math.max(0, totalSec))
  minutesRef.value = Math.floor(totalSec / 60)
  secondsRef.value = totalSec % 60
}

// Select all text on focus
export const selectOnFocus = (e: FocusEvent) => (e.target as HTMLInputElement).select()

// Format seconds with leading zero
export const padSeconds = (val: number) => val.toString().padStart(2, '0')

// Format total seconds to mm:ss
export const formatSeconds = (totalSeconds: number): string => {
  const mins = Math.floor(totalSeconds / 60)
  const secs = totalSeconds % 60
  return `${mins}:${secs.toString().padStart(2, '0')}`
}
