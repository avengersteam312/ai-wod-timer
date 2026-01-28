/**
 * Pinia store for Supabase authentication state
 * Manages user sessions, authentication, and auth-related operations
 */
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { User, Session, AuthError } from '@supabase/supabase-js'

/**
 * Auth state interface for the store
 */
export interface AuthState {
  user: User | null
  session: Session | null
  loading: boolean
  error: AuthError | null
}

export const useSupabaseAuthStore = defineStore('supabaseAuth', () => {
  // State
  const user = ref<User | null>(null)
  const session = ref<Session | null>(null)
  const loading = ref<boolean>(true)
  const error = ref<AuthError | null>(null)

  // Computed properties
  const isAuthenticated = computed(() => !!user.value)
  const userEmail = computed(() => user.value?.email ?? null)
  const userId = computed(() => user.value?.id ?? null)
  const userDisplayName = computed(() => {
    if (!user.value) return null
    const metadata = user.value.user_metadata
    return metadata?.display_name ?? metadata?.full_name ?? metadata?.name ?? user.value.email?.split('@')[0] ?? null
  })

  /**
   * Set the current user and session
   */
  const setAuth = (newUser: User | null, newSession: Session | null) => {
    user.value = newUser
    session.value = newSession
  }

  /**
   * Set loading state
   */
  const setLoading = (isLoading: boolean) => {
    loading.value = isLoading
  }

  /**
   * Set error state
   */
  const setError = (authError: AuthError | null) => {
    error.value = authError
  }

  /**
   * Clear error state
   */
  const clearError = () => {
    error.value = null
  }

  /**
   * Clear all auth state (used on sign out)
   */
  const clearAuth = () => {
    user.value = null
    session.value = null
    error.value = null
  }

  return {
    // State
    user,
    session,
    loading,
    error,

    // Computed
    isAuthenticated,
    userEmail,
    userId,
    userDisplayName,

    // State setters (internal use)
    setAuth,
    setLoading,
    setError,
    clearError,
    clearAuth
  }
})
