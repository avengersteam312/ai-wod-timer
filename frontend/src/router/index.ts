import { createRouter, createWebHistory } from 'vue-router'
import { watch } from 'vue'
import TimerView from '@/views/TimerView.vue'
import LoginView from '@/views/LoginView.vue'
import ForgotPasswordView from '@/views/ForgotPasswordView.vue'
import MyWorkoutsView from '@/views/MyWorkoutsView.vue'
import HistoryView from '@/views/HistoryView.vue'
import { useSupabaseAuthStore } from '@/stores/supabaseAuthStore'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/login',
      name: 'login',
      component: LoginView,
      meta: { requiresGuest: true }, // Only accessible when not logged in
    },
    {
      path: '/forgot-password',
      name: 'forgot-password',
      component: ForgotPasswordView,
      meta: { requiresGuest: true }, // Only accessible when not logged in
    },
    {
      path: '/',
      name: 'timer',
      component: TimerView,
      meta: { requiresAuth: true }, // Requires authentication
    },
    {
      path: '/workouts',
      name: 'workouts',
      component: MyWorkoutsView,
      meta: { requiresAuth: true }, // Requires authentication
    },
    {
      path: '/history',
      name: 'history',
      component: HistoryView,
      meta: { requiresAuth: true }, // Requires authentication
    },
  ],
})

// Navigation guard to protect routes
router.beforeEach(async (to, _from, next) => {
  const authStore = useSupabaseAuthStore()

  // Wait for auth to initialize with timeout
  if (authStore.loading) {
    const timeout = 2000 // 2 seconds max wait

    // Use Promise to wait for auth to load
    await new Promise<void>((resolve) => {
      // If already loaded, resolve immediately
      if (!authStore.loading) {
        resolve()
        return
      }

      // Watch for loading state to change
      const stopWatcher = watch(
        () => authStore.loading,
        (loading) => {
          if (!loading) {
            stopWatcher()
            resolve()
          }
        },
        { immediate: true }
      )

      // Timeout fallback
      setTimeout(() => {
        stopWatcher()
        resolve()
      }, timeout)
    })
  }
  
  // Route handling logic
  if (to.meta.requiresAuth && !authStore.isAuthenticated) {
    // Redirect to login if trying to access protected route
    next({ name: 'login', query: { redirect: to.fullPath } })
  } else if (to.meta.requiresGuest && authStore.isAuthenticated) {
    // Redirect to home if already logged in
    const redirect = (to.query.redirect as string) || '/'
    next(redirect)
  } else {
    next()
  }
})

export default router
