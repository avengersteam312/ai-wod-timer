/**
 * Pinia store for Supabase authentication state
 * Manages user sessions, authentication, and auth-related operations
 */
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { User, Session, AuthError } from '@supabase/supabase-js'
import { supabase } from '@/config/supabase'

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

  /**
   * Sign up a new user with email and password
   * @param email - User's email address
   * @param password - User's password
   * @returns Object with success status, requiresEmailConfirmation flag, and optional error
   */
  const signUp = async (email: string, password: string): Promise<{
    success: boolean
    requiresEmailConfirmation: boolean
    error: string | null
  }> => {
    clearError()
    setLoading(true)

    try {
      const { data, error: signUpError } = await supabase.auth.signUp({
        email,
        password
      })

      if (signUpError) {
        setError(signUpError)

        // Map common error messages to user-friendly ones
        let userFriendlyError = signUpError.message

        if (signUpError.message.includes('already registered') ||
            signUpError.message.includes('already been registered')) {
          userFriendlyError = 'An account with this email already exists'
        } else if (signUpError.message.includes('valid email')) {
          userFriendlyError = 'Please enter a valid email address'
        } else if (signUpError.message.includes('password') &&
                   (signUpError.message.includes('short') ||
                    signUpError.message.includes('least') ||
                    signUpError.message.includes('characters'))) {
          userFriendlyError = 'Password must be at least 6 characters long'
        }

        return {
          success: false,
          requiresEmailConfirmation: false,
          error: userFriendlyError
        }
      }

      // Check if email confirmation is required
      // If session is null but user exists, email confirmation is pending
      const requiresEmailConfirmation = data.user !== null && data.session === null

      if (data.session && data.user) {
        // User is automatically signed in (email confirmation not required)
        setAuth(data.user, data.session)
      }

      return {
        success: true,
        requiresEmailConfirmation,
        error: null
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'An unexpected error occurred'
      return {
        success: false,
        requiresEmailConfirmation: false,
        error: errorMessage
      }
    } finally {
      setLoading(false)
    }
  }

  /**
   * Sign in an existing user with email and password
   * @param email - User's email address
   * @param password - User's password
   * @returns Object with success status and optional error message
   */
  const signIn = async (email: string, password: string): Promise<{
    success: boolean
    error: string | null
  }> => {
    clearError()
    setLoading(true)

    try {
      const { data, error: signInError } = await supabase.auth.signInWithPassword({
        email,
        password
      })

      if (signInError) {
        setError(signInError)

        // Map common error messages to user-friendly ones
        let userFriendlyError = signInError.message

        if (signInError.message.includes('Invalid login credentials') ||
            signInError.message.includes('invalid_credentials')) {
          userFriendlyError = 'Invalid email or password'
        } else if (signInError.message.includes('Email not confirmed') ||
                   signInError.message.includes('email_not_confirmed')) {
          userFriendlyError = 'Please confirm your email address before signing in'
        } else if (signInError.message.includes('valid email')) {
          userFriendlyError = 'Please enter a valid email address'
        } else if (signInError.message.includes('rate limit') ||
                   signInError.message.includes('too many requests')) {
          userFriendlyError = 'Too many login attempts. Please try again later'
        }

        return {
          success: false,
          error: userFriendlyError
        }
      }

      if (data.session && data.user) {
        setAuth(data.user, data.session)
      }

      return {
        success: true,
        error: null
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : 'An unexpected error occurred'
      return {
        success: false,
        error: errorMessage
      }
    } finally {
      setLoading(false)
    }
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
    clearAuth,

    // Auth actions
    signUp,
    signIn
  }
})
