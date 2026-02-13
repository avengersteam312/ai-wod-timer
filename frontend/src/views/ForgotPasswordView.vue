<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useSupabaseAuthStore } from '@/stores/supabaseAuthStore'
import Button from '@/components/ui/Button.vue'
import Card from '@/components/ui/Card.vue'
import { validateEmail } from '@/utils/validation'

const router = useRouter()
const authStore = useSupabaseAuthStore()

const email = ref('')
const isLoading = ref(false)
const error = ref<string | null>(null)
const emailError = ref<string | null>(null)
const success = ref(false)

const handleSubmit = async () => {
  // Clear previous errors
  error.value = null
  emailError.value = null

  // Validate email
  const emailValidation = validateEmail(email.value)
  if (!emailValidation.isValid) {
    emailError.value = emailValidation.error ?? null
    return
  }

  isLoading.value = true
  error.value = null
  success.value = false

  const result = await authStore.resetPassword(email.value)

  if (!result.success) {
    error.value = result.error
    success.value = false
  } else {
    success.value = true
    error.value = null
  }

  isLoading.value = false
}

const goToLogin = () => {
  router.push('/login')
}

const clearEmailError = () => {
  emailError.value = null
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-background px-4">
    <Card class="w-full max-w-md p-8">
      <div class="space-y-6">
        <div class="text-center">
          <h1 class="text-3xl font-bold text-foreground font-athletic">
            Reset Password
          </h1>
          <p class="mt-2 text-sm text-muted-foreground">
            Enter your email address and we'll send you a link to reset your password.
          </p>
        </div>

        <form @submit.prevent="handleSubmit" class="space-y-4">
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

          <div v-if="success" class="p-3 bg-green-500/10 border border-green-500/20 rounded-md">
            <p class="text-sm text-green-400">
              Password reset email sent! Please check your inbox and follow the instructions to reset your password.
            </p>
          </div>

          <div v-if="error && !success" class="p-3 bg-destructive/10 border border-destructive/20 rounded-md">
            <p class="text-sm text-destructive">{{ error }}</p>
          </div>

          <div class="flex gap-3">
            <Button
              type="button"
              variant="outline"
              @click="goToLogin"
              :disabled="isLoading"
              class="flex-1"
            >
              Back to Login
            </Button>
            <Button
              type="submit"
              :disabled="isLoading"
              class="flex-1 text-base font-semibold py-3"
            >
              {{ isLoading ? 'Sending...' : 'Send Reset Link' }}
            </Button>
          </div>
        </form>

        <div class="text-center">
          <span class="text-sm text-muted-foreground">
            Remember your password?
            <button
              @click="goToLogin"
              class="text-sm text-primary hover:text-primary/80 font-medium ml-1"
            >
              Sign in
            </button>
          </span>
        </div>
      </div>
    </Card>
  </div>
</template>
