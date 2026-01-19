/**
 * Authentication composable using Firebase Auth
 * Provides sign in, sign up, sign out, and auth state management
 */
import { ref } from 'vue'
import {
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut as firebaseSignOut,
  signInWithPopup,
  GoogleAuthProvider,
  onAuthStateChanged,
  onIdTokenChanged,
  sendPasswordResetEmail,
  type User,
  type UserCredential
} from 'firebase/auth'

import { auth } from '@/config/firebase'

// Firebase Auth errors have a code property
interface FirebaseAuthError extends Error {
  code?: string
}

// Global auth state
const currentUser = ref<User | null>(null)
const isLoading = ref(true)
const error = ref<string | null>(null)

// Listen to auth state changes
let unsubscribe: (() => void) | null = null
let tokenUnsubscribe: (() => void) | null = null

export function useAuth() {
  /**
   * Initialize auth state listener
   * Call this in your main App component or router
   */
  const initAuth = () => {
    if (unsubscribe) return // Already initialized

    isLoading.value = true
    
    // Listen to auth state changes
    unsubscribe = onAuthStateChanged(
      auth,
      (user) => {
        currentUser.value = user
        isLoading.value = false
        error.value = null
      },
      (err) => {
        error.value = err.message
        isLoading.value = false
        currentUser.value = null
      }
    )

    // Listen to token refresh events to automatically refresh expired tokens
    tokenUnsubscribe = onIdTokenChanged(
      auth,
      async (user) => {
        if (user) {
          // Force refresh token to ensure we have a valid token
          try {
            await user.getIdToken(true)
          } catch (err) {
            console.warn('Failed to refresh token:', err)
          }
        }
      }
    )
  }

  /**
   * Sign in with email and password
   */
  const signIn = async (email: string, password: string): Promise<UserCredential> => {
    try {
      error.value = null
      const userCredential = await signInWithEmailAndPassword(auth, email, password)
      return userCredential
    } catch (err) {
      const authError = err as FirebaseAuthError
      error.value = authError.message || 'Failed to sign in'
      throw err
    }
  }

  /**
   * Sign up (register) with email and password
   */
  const signUp = async (email: string, password: string): Promise<UserCredential> => {
    try {
      error.value = null
      const userCredential = await createUserWithEmailAndPassword(auth, email, password)
      return userCredential
    } catch (err) {
      const authError = err as FirebaseAuthError
      error.value = authError.message || 'Failed to sign up'
      throw err
    }
  }

  /**
   * Sign in with Google
   */
  const signInWithGoogle = async (): Promise<UserCredential> => {
    try {
      error.value = null
      const provider = new GoogleAuthProvider()
      const userCredential = await signInWithPopup(auth, provider)
      return userCredential
    } catch (err) {
      const authError = err as FirebaseAuthError
      error.value = authError.message || 'Failed to sign in with Google'
      throw err
    }
  }

  /**
   * Sign out the current user
   */
  const signOut = async (): Promise<void> => {
    try {
      error.value = null
      await firebaseSignOut(auth)
    } catch (err) {
      const authError = err as FirebaseAuthError
      error.value = authError.message || 'Failed to sign out'
      throw err
    }
  }

  /**
   * Send password reset email
   */
  const resetPassword = async (email: string): Promise<void> => {
    try {
      error.value = null
      await sendPasswordResetEmail(auth, email)
    } catch (err) {
      const authError = err as FirebaseAuthError
      error.value = authError.message || 'Failed to send password reset email'
      throw err
    }
  }

  /**
   * Get the current user's ID token
   * This is what you send to your backend for authentication
   * @param forceRefresh - If true, forces a token refresh even if current token is valid
   */
  const getIdToken = async (forceRefresh: boolean = false): Promise<string | null> => {
    if (!currentUser.value) return null
    try {
      // Force refresh if requested or if token might be expired
      return await currentUser.value.getIdToken(forceRefresh)
    } catch (err) {
      const authError = err as FirebaseAuthError
      error.value = authError.message || 'Failed to get ID token'
      return null
    }
  }

  /**
   * Cleanup auth listeners
   */
  const cleanup = () => {
    if (unsubscribe) {
      unsubscribe()
      unsubscribe = null
    }
    if (tokenUnsubscribe) {
      tokenUnsubscribe()
      tokenUnsubscribe = null
    }
  }

  return {
    // State
    currentUser,
    isLoading,
    error,
    
    // Methods
    initAuth,
    signIn,
    signUp,
    signInWithGoogle,
    signOut,
    resetPassword,
    getIdToken,
    cleanup
  }
}
