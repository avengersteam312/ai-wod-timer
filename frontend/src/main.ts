import { createApp } from 'vue'
import { createPinia } from 'pinia'
import router from './router'
import './style.css'
import App from './App.vue'
import { useSupabaseAuthStore } from './stores/supabaseAuthStore'

const app = createApp(App)

app.use(createPinia())
app.use(router)

// Initialize auth store after Pinia is set up
const authStore = useSupabaseAuthStore()
authStore.initialize()

app.mount('#app')
