import { createApp } from 'vue'
import { createPinia } from 'pinia'
import router from './router'
import './style.css'
import App from './App.vue'
import { useSupabaseAuthStore } from './stores/supabaseAuthStore'
import { configureObservability } from './observability'

const app = createApp(App)

// Wire Sentry before mounting — captures errors from all lifecycle hooks
configureObservability(app)

app.use(createPinia())
app.use(router)

// Initialize auth store after Pinia is set up
const authStore = useSupabaseAuthStore()
authStore.initialize()

app.mount('#app')
