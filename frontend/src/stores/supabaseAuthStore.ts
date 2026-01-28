/**
 * Pinia store for Supabase authentication state
 * Manages user sessions, authentication, and auth-related operations
 */
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import type { User, Session, AuthError, Subscription } from '@supabase/supabase-js'
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
  const initialized = ref<boolean>(false)

  // Auth state change subscription (stored to allow cleanup)
  let authSubscription: Subscription | null = null

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

  /**
   * Sign out the current user
   * @returns Object with success status and optional error message
   */
  const signOut = async (): Promise<{
    success: boolean
    error: string | null
  }> => {
    clearError()
    setLoading(true)

    try {
      const { error: signOutError } = await supabase.auth.signOut()

      if (signOutError) {
        setError(signOutError)
        return {
          success: false,
          error: signOutError.message
        }
      }

      // Clear user and session from Pinia state
      clearAuth()

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

  /**
   * Initialize the auth store by fetching the current session
   * and setting up auth state change listeners.
   * Should be called once when the app starts.
   */
  const initialize = async (): Promise<void> => {
    // Prevent multiple initializations
    if (initialized.value) {
      return
    }

    setLoading(true)

    try {
      // Get the current session from Supabase (handles token refresh automatically)
      const { data: { session: currentSession }, error: sessionError } = await supabase.auth.getSession()

      if (sessionError) {
        console.error('Error getting session:', sessionError.message)
        setError(sessionError)
      } else if (currentSession) {
        setAuth(currentSession.user, currentSession)
      }

      // Set up auth state change listener
      // This handles: sign in, sign out, token refresh, password recovery, etc.
      const { data: { subscription } } = supabase.auth.onAuthStateChange(
        (event, newSession) => {
          // Handle different auth events
          switch (event) {
            case 'SIGNED_IN':
            case 'TOKEN_REFRESHED':
            case 'USER_UPDATED':
              if (newSession) {
                setAuth(newSession.user, newSession)
              }
              break
            case 'SIGNED_OUT':
              clearAuth()
              break
            case 'PASSWORD_RECOVERY':
              // User clicked password reset link - session may be partial
              if (newSession) {
                setAuth(newSession.user, newSession)
              }
              break
            case 'INITIAL_SESSION':
              // Initial session event (fired on first load) - already handled above
              break
          }
        }
      )

      authSubscription = subscription
      initialized.value = true
    } catch (err) {
      console.error('Error initializing auth:', err)
    } finally {
      setLoading(false)
    }
  }

  /**
   * Clean up the auth state change listener.
   * Should be called when the app is unmounted or during cleanup.
   */
  const cleanup = (): void => {
    if (authSubscription) {
      authSubscription.unsubscribe()
      authSubscription = null
    }
    initialized.value = false
  }

  return {
    // State
    user,
    session,
    loading,
    error,
    initialized,

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
    signIn,
    signOut,

    // Session persistence
    initialize,
    cleanup
  }
})
