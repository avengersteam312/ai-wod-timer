/**
 * Pinia store for authentication state
 * Uses Firebase Auth via the useAuth composable
 */
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { useAuth } from '@/composables/useAuth'
import type { User } from 'firebase/auth'

export const useAuthStore = defineStore('auth', () => {
  const { currentUser, isLoading, error, initAuth, signIn, signUp, signInWithGoogle, signOut, resetPassword, getIdToken, cleanup } = useAuth()

  // Computed properties
  const user = computed(() => currentUser.value)
  const isAuthenticated = computed(() => !!currentUser.value)
  const userEmail = computed(() => currentUser.value?.email || null)
  const userId = computed(() => currentUser.value?.uid || null)

  /**
   * Initialize auth state listener
   * Call this when your app starts (e.g., in main.ts or App.vue)
   */
  const initialize = () => {
    initAuth()
  }

  /**
   * Sign in with email and password
   */
  const login = async (email: string, password: string) => {
    await signIn(email, password)
  }

  /**
   * Register new user with email and password
   */
  const register = async (email: string, password: string) => {
    await signUp(email, password)
  }

  /**
   * Sign in with Google
   */
  const loginWithGoogle = async () => {
    await signInWithGoogle()
  }

  /**
   * Sign out current user
   */
  const logout = async () => {
    await signOut()
  }

  /**
   * Send password reset email
   */
  const sendPasswordReset = async (email: string) => {
    await resetPassword(email)
  }

  /**
   * Get ID token for backend authentication
   * @param forceRefresh - If true, forces a token refresh even if current token is valid
   */
  const getToken = async (forceRefresh: boolean = false): Promise<string | null> => {
    return await getIdToken(forceRefresh)
  }

  /**
   * Cleanup auth listener (call on app unmount)
   */
  const cleanupAuth = () => {
    cleanup()
  }

  return {
    // State
    user,
    isLoading,
    error,
    
    // Computed
    isAuthenticated,
    userEmail,
    userId,
    
    // Actions
    initialize,
    login,
    register,
    loginWithGoogle,
    logout,
    sendPasswordReset,
    getToken,
    cleanupAuth
  }
})
