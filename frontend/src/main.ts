import { createApp } from 'vue'
import { createPinia } from 'pinia'
import router from './router'
import './style.css'
import App from './App.vue'
import { useAuthStore } from './stores/authStore'

const app = createApp(App)

app.use(createPinia())
app.use(router)

// Initialize auth store after Pinia is set up
const authStore = useAuthStore()
authStore.initialize()

app.mount('#app')
