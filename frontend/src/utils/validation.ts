/**
 * Validation utilities for email and password
 */

/**
 * Validates email format
 * @param email - Email address to validate
 * @returns Object with isValid boolean and error message
 */
export function validateEmail(email: string): { isValid: boolean; error?: string } {
  if (!email || email.trim() === '') {
    return { isValid: false, error: 'Email is required' }
  }

  // Basic email regex pattern
  // Matches: user@example.com, user.name@example.co.uk, etc.
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  
  if (!emailRegex.test(email.trim())) {
    return { isValid: false, error: 'Please enter a valid email address (e.g., user@example.com)' }
  }

  // Check for common typos
  if (email.includes('..')) {
    return { isValid: false, error: 'Email cannot contain consecutive dots' }
  }

  if (email.startsWith('.') || email.endsWith('.')) {
    return { isValid: false, error: 'Email cannot start or end with a dot' }
  }

  return { isValid: true }
}

/**
 * Validates password strength
 * @param password - Password to validate
 * @param isRegistration - Whether this is for registration (stricter rules) or login
 * @returns Object with isValid boolean and error message
 */
export function validatePassword(password: string, isRegistration: boolean = false): { isValid: boolean; error?: string } {
  if (!password || password.trim() === '') {
    return { isValid: false, error: 'Password is required' }
  }

  // Minimum length check (at least 6 characters)
  if (password.length < 6) {
    return { isValid: false, error: 'Password must be at least 6 characters long' }
  }

  // For registration, apply stricter password requirements
  if (isRegistration) {
    // Check for at least one letter
    if (!/[a-zA-Z]/.test(password)) {
      return { isValid: false, error: 'Password must contain at least one letter' }
    }

    // Check for at least one number or special character
    if (!/[0-9!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password)) {
      return { 
        isValid: false, 
        error: 'Password must contain at least one number or special character' 
      }
    }

    // Check for common weak passwords
    const commonPasswords = ['password', '123456', 'password123', 'qwerty', 'abc123']
    if (commonPasswords.some(common => password.toLowerCase().includes(common))) {
      return { 
        isValid: false, 
        error: 'Password is too common. Please choose a stronger password' 
      }
    }
  }

  // Maximum length check (reasonable limit)
  if (password.length > 128) {
    return { isValid: false, error: 'Password is too long (maximum 128 characters)' }
  }

  return { isValid: true }
}

/**
 * Validates both email and password
 * @param email - Email address
 * @param password - Password
 * @param isRegistration - Whether this is for registration
 * @returns Object with isValid boolean and errors object
 */
export function validateCredentials(
  email: string, 
  password: string, 
  isRegistration: boolean = false
): { isValid: boolean; errors: { email?: string; password?: string } } {
  const emailValidation = validateEmail(email)
  const passwordValidation = validatePassword(password, isRegistration)

  const errors: { email?: string; password?: string } = {}
  
  if (!emailValidation.isValid) {
    errors.email = emailValidation.error
  }
  
  if (!passwordValidation.isValid) {
    errors.password = passwordValidation.error
  }

  return {
    isValid: emailValidation.isValid && passwordValidation.isValid,
    errors
  }
}
