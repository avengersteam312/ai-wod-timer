<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useSupabaseAuthStore } from '@/stores/supabaseAuthStore'
import Button from '@/components/ui/Button.vue'
import Card from '@/components/ui/Card.vue'
import { validateCredentials, validateEmail } from '@/utils/validation'
import { Eye, EyeOff } from 'lucide-vue-next'

const router = useRouter()

// Reference icons for TypeScript
void [Eye, EyeOff]
const authStore = useSupabaseAuthStore()

const email = ref('')
const password = ref('')
const isLoading = ref(false)
const error = ref<string | null>(null)
const emailError = ref<string | null>(null)
const passwordError = ref<string | null>(null)
const isLogin = ref(true) // Toggle between login and register
const showPassword = ref(false) // Password visibility toggle
const showPasswordReset = ref(false) // Show password reset form
const resetEmail = ref('') // Email for password reset
const resetEmailError = ref<string | null>(null)
const resetSuccess = ref(false) // Success message for password reset
const signUpSuccess = ref(false) // Success message for email confirmation after signup

const handleGoogleSignIn = async () => {
  isLoading.value = true
  error.value = null

  const result = await authStore.signInWithGoogle()

  if (!result.success) {
    error.value = result.error
    isLoading.value = false
    return
  }

  // Note: For OAuth, redirect is handled by Supabase.
  // The actual auth completion is handled by onAuthStateChange
  // which will redirect the user via the router guard.
  isLoading.value = false
}

const handleSubmit = async () => {
  // Clear previous errors
  error.value = null
  emailError.value = null
  passwordError.value = null

  // Validate credentials before submission
  const validation = validateCredentials(email.value, password.value, !isLogin.value)

  if (!validation.isValid) {
    // Set field-specific errors
    if (validation.errors.email) {
      emailError.value = validation.errors.email
    }
    if (validation.errors.password) {
      passwordError.value = validation.errors.password
    }
    // Also set general error if both fields have issues
    if (validation.errors.email && validation.errors.password) {
      error.value = 'Please fix the errors above'
    }
    return
  }

  isLoading.value = true
  error.value = null

  if (isLogin.value) {
    const result = await authStore.signIn(email.value, password.value)

    if (!result.success) {
      error.value = result.error
      isLoading.value = false
      return
    }
  } else {
    const result = await authStore.signUp(email.value, password.value)

    if (!result.success) {
      error.value = result.error
      isLoading.value = false
      return
    }

    // Handle email confirmation requirement
    if (result.requiresEmailConfirmation) {
      error.value = null
      isLoading.value = false
      // Show success message for email confirmation
      signUpSuccess.value = true
      return
    }
  }

  isLoading.value = false
  // Redirect to the original destination or timer view
  const redirect = router.currentRoute.value.query.redirect as string
  router.push(redirect || '/')
}

const toggleMode = () => {
  isLogin.value = !isLogin.value
  error.value = null
  emailError.value = null
  passwordError.value = null
  showPasswordReset.value = false
  resetSuccess.value = false
  signUpSuccess.value = false
}

const handleForgotPassword = () => {
  // Navigate to dedicated forgot password page
  router.push('/forgot-password')
}

const handlePasswordReset = async () => {
  // Clear previous errors
  error.value = null
  resetEmailError.value = null

  // Validate email
  const emailValidation = validateEmail(resetEmail.value)
  if (!emailValidation.isValid) {
    resetEmailError.value = emailValidation.error ?? null
    return
  }

  isLoading.value = true
  error.value = null
  resetSuccess.value = false

  const result = await authStore.resetPassword(resetEmail.value)

  if (!result.success) {
    error.value = result.error
    resetSuccess.value = false
  } else {
    resetSuccess.value = true
    error.value = null
  }

  isLoading.value = false
}

const backToLogin = () => {
  showPasswordReset.value = false
  resetEmail.value = ''
  resetSuccess.value = false
  error.value = null
  resetEmailError.value = null
}

// Clear field errors when user types
const clearEmailError = () => {
  emailError.value = null
}

const clearPasswordError = () => {
  passwordError.value = null
}

const clearResetEmailError = () => {
  resetEmailError.value = null
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-background px-4">
    <Card class="w-full max-w-md p-8">
      <div class="space-y-6">
        <div class="text-center">
          <h1 class="text-3xl font-bold text-foreground font-athletic">
            {{ showPasswordReset ? 'Reset Password' : (isLogin ? 'Sign In' : 'Sign Up') }}
          </h1>
          <p v-if="!showPasswordReset" class="mt-2 text-sm text-muted-foreground">
            {{ isLogin ? 'Sign in to your account' : 'Create a new account' }}
          </p>
        </div>

        <!-- Password Reset Form -->
        <form v-if="showPasswordReset" @submit.prevent="handlePasswordReset" class="space-y-4">
          <div>
            <h2 class="text-xl font-semibold text-foreground mb-2 font-athletic">Reset Password</h2>
            <p class="text-sm text-muted-foreground mb-4">
              Enter your email address and we'll send you a link to reset your password.
            </p>
          </div>

          <div>
            <label for="reset-email" class="block text-sm font-medium text-foreground mb-1">
              Email Address <span class="text-red-500">*</span>
            </label>
            <input
              id="reset-email"
              v-model="resetEmail"
              type="email"
              required
              @input="clearResetEmailError"
              :class="[
                'w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-ring focus:border-ring text-foreground bg-background',
                resetEmailError ? 'border-destructive' : 'border-input'
              ]"
              placeholder="you@example.com"
            />
            <p v-if="resetEmailError" class="mt-1 text-sm text-destructive">{{ resetEmailError }}</p>
          </div>

          <div v-if="resetSuccess" class="p-3 bg-green-500/10 border border-green-500/20 rounded-md">
            <p class="text-sm text-green-400">
              Password reset email sent! Please check your inbox and follow the instructions to reset your password.
            </p>
          </div>

          <div v-if="error && !resetSuccess" class="p-3 bg-destructive/10 border border-destructive/20 rounded-md">
            <p class="text-sm text-destructive">{{ error }}</p>
          </div>

          <div class="flex gap-3">
            <Button
              type="button"
              variant="outline"
              @click="backToLogin"
              :disabled="isLoading"
              class="flex-1"
            >
              Back
            </Button>
            <Button
              type="submit"
              :disabled="isLoading"
              class="flex-1 text-base font-semibold py-3"
            >
              {{ isLoading ? 'Sending...' : 'Reset' }}
            </Button>
          </div>
        </form>

        <!-- Login/Register Form -->
        <form v-else @submit.prevent="handleSubmit" class="space-y-4">
          <div>
            <label for="email" class="block text-sm font-medium text-foreground mb-1">
              Email Address <span class="text-red-500">*</span>
            </label>
            <input
              id="email"
              v-model="email"
              type="email"
              required
              @input="clearEmailError"
              :class="[
                'w-full px-3 py-2 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-ring focus:border-ring text-foreground bg-background',
                emailError ? 'border-destructive' : 'border-input'
              ]"
              placeholder="you@example.com"
            />
            <p v-if="emailError" class="mt-1 text-sm text-destructive">{{ emailError }}</p>
          </div>

          <div>
            <div class="flex items-center justify-between mb-1">
              <label for="password" class="block text-sm font-medium text-foreground">
                Password <span class="text-red-500">*</span>
              </label>
              <button
                v-if="isLogin && !showPasswordReset"
                type="button"
                class="text-sm text-primary hover:text-primary/80 font-medium"
                @click="handleForgotPassword"
              >
                Forgot Password?
              </button>
            </div>
            <div class="relative">
              <input
                id="password"
                v-model="password"
                :type="showPassword ? 'text' : 'password'"
                required
                minlength="6"
                @input="clearPasswordError"
                :class="[
                  'w-full px-3 py-2 pr-10 border rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-ring focus:border-ring text-foreground bg-background',
                  passwordError ? 'border-destructive' : 'border-input'
                ]"
                placeholder="••••••••"
              />
              <button
                type="button"
                @click="showPassword = !showPassword"
                class="absolute right-2 top-1/2 -translate-y-1/2 p-1 text-muted-foreground hover:text-foreground focus:outline-none focus:ring-2 focus:ring-ring rounded"
                aria-label="Toggle password visibility"
              >
                <Eye v-if="!showPassword" class="h-5 w-5" />
                <EyeOff v-else class="h-5 w-5" />
              </button>
            </div>
            <p v-if="passwordError" class="mt-1 text-sm text-destructive">{{ passwordError }}</p>
            <p v-if="!isLogin && !passwordError" class="mt-1 text-xs text-muted-foreground">
              Password must be at least 6 characters and contain letters and numbers/special characters
            </p>
          </div>

          <div v-if="error" class="p-3 bg-destructive/10 border border-destructive/20 rounded-md">
            <p class="text-sm text-destructive">{{ error }}</p>
          </div>

          <div v-if="signUpSuccess" class="p-3 bg-green-500/10 border border-green-500/20 rounded-md">
            <p class="text-sm text-green-400">
              Account created successfully! Please check your email to confirm your account before signing in.
            </p>
          </div>

          <Button
            type="submit"
            :disabled="isLoading || signUpSuccess"
            class="w-full text-base font-semibold py-3"
          >
            {{ isLoading ? 'Loading...' : (isLogin ? 'Log In' : 'Sign Up') }}
          </Button>
        </form>

        <template v-if="!showPasswordReset">
          <div class="relative">
            <div class="absolute inset-0 flex items-center">
              <div class="w-full border-t border-border"></div>
            </div>
            <div class="relative flex justify-center">
              <span class="px-2 bg-background text-xs text-muted-foreground">or</span>
            </div>
          </div>

          <Button
            type="button"
            variant="outline"
            @click="handleGoogleSignIn"
            :disabled="isLoading"
            class="w-full"
          >
            <svg class="w-5 h-5 mr-2" viewBox="0 0 24 24">
              <path
                fill="#4285F4"
                d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
              />
              <path
                fill="#34A853"
                d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
              />
              <path
                fill="#FBBC05"
                d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
              />
              <path
                fill="#EA4335"
                d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
              />
            </svg>
            {{ isLogin ? 'Sign in with Google' : 'Sign up with Google' }}
          </Button>

          <div class="text-center">
            <span class="text-sm text-muted-foreground">
              {{ isLogin ? "Don't have an account? " : 'Already have an account? ' }}
              <button
                @click="toggleMode"
                class="text-sm text-primary hover:text-primary/80 font-medium"
              >
                {{ isLogin ? 'Sign up' : 'Sign in' }}
              </button>
            </span>
          </div>
        </template>
      </div>
    </Card>
  </div>
</template>
