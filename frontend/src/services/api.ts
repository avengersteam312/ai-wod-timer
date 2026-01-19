import axios, { type AxiosInstance, type InternalAxiosRequestConfig } from 'axios'
import type { WorkoutParseRequest, ParsedWorkout } from '@/types/workout'
import { mockWorkoutApi } from './mockApi'
import { useAuthStore } from '@/stores/authStore'

// Set to true to use mock API (no backend needed)
const USE_MOCK_API = false

const api: AxiosInstance = axios.create({
  baseURL: '/api/v1',
  headers: {
    'Content-Type': 'application/json',
  },
})

// Request interceptor to add Firebase auth token to requests
api.interceptors.request.use(
  async (config: InternalAxiosRequestConfig) => {
    const authStore = useAuthStore()
    
    // Get the Firebase ID token if user is authenticated
    if (authStore.isAuthenticated) {
      try {
        const token = await authStore.getToken()
        if (token && config.headers) {
          config.headers.Authorization = `Bearer ${token}`
        }
      } catch (error) {
        console.error('Failed to get auth token:', error)
      }
    }
    
    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)

// Response interceptor to handle auth errors
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    // If we get a 401, try to refresh the token and retry once
    if (error.response?.status === 401) {
      const authStore = useAuthStore()
      
      // Prevent infinite retry loops: check if this request was already retried
      const config = error.config as InternalAxiosRequestConfig & { _retry?: boolean }
      if (config._retry) {
        // Already retried once, don't retry again
        return Promise.reject(error)
      }
      
      // Try to refresh the token
      if (authStore.isAuthenticated) {
        try {
          // Mark this request as retried to prevent infinite loops
          config._retry = true
          
          // Force token refresh
          const newToken = await authStore.getToken(true)
          
          // If we got a new token, retry the original request
          if (newToken && config.headers) {
            config.headers.Authorization = `Bearer ${newToken}`
            return api.request(config)
          }
        } catch (refreshError) {
          // Token refresh failed, user needs to re-authenticate
          console.error('Token refresh failed:', refreshError)
        }
      }
      
      // If refresh failed or user not authenticated, redirect to login
      // Note: Don't auto-logout here as router guard will handle redirect
    }
    return Promise.reject(error)
  }
)

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
