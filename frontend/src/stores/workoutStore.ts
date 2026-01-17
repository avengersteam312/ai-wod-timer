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
      currentWorkout.value = result
      return result
    } catch (err: any) {
      error.value = err.response?.data?.detail || err.message || 'Failed to parse workout'
      throw err
    } finally {
      isLoading.value = false
    }
  }

  const clearWorkout = () => {
    currentWorkout.value = null
    error.value = null
  }

  return {
    currentWorkout,
    isLoading,
    error,
    parseWorkout,
    clearWorkout,
  }
})
