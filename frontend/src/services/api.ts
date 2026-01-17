import axios from 'axios'
import type { WorkoutParseRequest, ParsedWorkout } from '@/types/workout'
import { mockWorkoutApi } from './mockApi'

// Set to true to use mock API (no backend needed)
const USE_MOCK_API = false

const api = axios.create({
  baseURL: '/api/v1',
  headers: {
    'Content-Type': 'application/json',
  },
})

export const workoutApi = {
  parseWorkout: async (request: WorkoutParseRequest): Promise<ParsedWorkout> => {
    // Use mock API if enabled (for testing without backend)
    if (USE_MOCK_API) {
      return mockWorkoutApi.parseWorkout(request)
    }

    const response = await api.post<ParsedWorkout>('/timer/parse', request)
    return response.data
  },
}

export default api
