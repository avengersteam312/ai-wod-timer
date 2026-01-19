/**
 * Maps Firebase authentication error codes to user-friendly messages
 */

interface FirebaseError {
  code?: string
  message?: string
  error?: {
    code?: string
    message?: string
  }
}

export function getAuthErrorMessage(error: FirebaseError | Error | unknown): string {
  // Handle Firebase Auth errors
  const code = error?.code || error?.error?.code || ''
  
  // Firebase Auth error codes
  // Note: Firebase v9+ uses 'auth/invalid-credential' instead of separate 
  // 'auth/wrong-password' and 'auth/user-not-found' for security
  const errorMessages: Record<string, string> = {
    // Authentication errors (legacy codes for older Firebase versions)
    'auth/wrong-password': 'Incorrect password. Please try again.',
    'auth/user-not-found': 'No account found with this email address.',
    
    // Modern Firebase error codes
    'auth/invalid-credential': 'Invalid email or password. Please check your credentials and try again.',
    'auth/invalid-email': 'Please enter a valid email address.',
    'auth/user-disabled': 'This account has been disabled. Please contact support.',
    'auth/too-many-requests': 'Too many failed attempts. Please wait a moment and try again.',
    'auth/operation-not-allowed': 'This sign-in method is not enabled.',
    
    // Registration errors
    'auth/email-already-in-use': 'An account with this email already exists. Please sign in instead.',
    'auth/weak-password': 'Password is too weak. Please use at least 6 characters.',
    
    // Network errors
    'auth/network-request-failed': 'Network error. Please check your connection and try again.',
    
    // Generic errors
    'auth/internal-error': 'An internal error occurred. Please try again.',
  }
  
  // Check if we have a specific message for this error code
  if (code && errorMessages[code]) {
    return errorMessages[code]
  }
  
  // Check if error message is already user-friendly
  const message = error?.message || error?.error?.message || ''
  
  // If it's a Firebase error message, try to extract a user-friendly version
  if (message.includes('auth/')) {
    // Extract the error code from the message
    const match = message.match(/auth\/[a-z-]+/)
    if (match && errorMessages[match[0]]) {
      return errorMessages[match[0]]
    }
  }
  
  // Return a generic message if we can't map it
  return message || 'An error occurred. Please try again.'
}
