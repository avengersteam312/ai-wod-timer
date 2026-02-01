import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'path'

// Check if this is a native/Capacitor build
const isNativeBuild = process.env.VITE_NATIVE_BUILD === 'true'

// https://vite.dev/config/
export default defineConfig({
  base: './',
  plugins: [vue()],
  define: {
    // Build-time flag for Capacitor features
    // Set VITE_NATIVE_BUILD=true when building for iOS/Android
    __CAPACITOR_ENABLED__: isNativeBuild,
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  build: {
    rollupOptions: {
      // Externalize Capacitor packages for web builds to avoid resolution errors
      external: isNativeBuild ? [] : [
        /@capacitor\/.*/,
        /@capacitor-community\/.*/,
      ],
    },
  },
  server: {
    port: 5173,
    proxy: {
      '/api': {
        // Use VITE_API_URL env var in Docker, fallback to localhost for local dev
        target: process.env.VITE_API_URL || 'http://localhost:8000',
        changeOrigin: true,
      },
    },
  },
})
