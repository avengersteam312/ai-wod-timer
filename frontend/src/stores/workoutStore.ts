import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { ParsedWorkout } from '@/types/workout'
import { workoutApi } from '@/services/api'

export const useWorkoutStore = defineStore('workout', () => {
  const currentWorkout = ref<ParsedWorkout | null>(null)
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  const parseWorkout = async (workoutText: string) => {
    isLoading.value = true
    error.value = null

    try {
      const result = await workoutApi.parseWorkout({ workout_text: workoutText })
      // Use the user's input as workout notes
      result.notes = workoutText
      currentWorkout.value = result
      return result
    } catch (err) {
      // Handle Axios errors with proper typing
      const axiosError = err as { response?: { data?: { detail?: string } }; message?: string }
      error.value = axiosError.response?.data?.detail || axiosError.message || 'Failed to parse workout'
      throw err
    } finally {
      isLoading.value = false
    }
  }

  const clearWorkout = () => {
    currentWorkout.value = null
    error.value = null
  }

  const setManualWorkout = (workout: ParsedWorkout) => {
    currentWorkout.value = workout
    error.value = null
  }

  return {
    currentWorkout,
    isLoading,
    error,
    parseWorkout,
    clearWorkout,
    setManualWorkout,
  }
})
