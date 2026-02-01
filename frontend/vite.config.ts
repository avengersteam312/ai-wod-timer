import { defineConfig, type Plugin } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'path'

// Check if this is a native/Capacitor build
const isNativeBuild = process.env.VITE_NATIVE_BUILD === 'true'

/**
 * Vite plugin to stub out Capacitor modules on web builds.
 * This prevents Vite from trying to resolve @capacitor/* packages
 * when building for web deployment.
 */
function capacitorStubPlugin(): Plugin {
  const capacitorPackages = [
    '@capacitor/core',
    '@capacitor/app',
    '@capacitor/haptics',
    '@capacitor/preferences',
    '@capacitor-community/keep-awake',
  ]

  return {
    name: 'capacitor-stub',
    enforce: 'pre',
    resolveId(id) {
      if (!isNativeBuild && capacitorPackages.some(pkg => id === pkg || id.startsWith(pkg + '/'))) {
        return `\0capacitor-stub:${id}`
      }
      return null
    },
    load(id) {
      if (id.startsWith('\0capacitor-stub:')) {
        // Return stub module that exports empty objects/functions
        return `
          export const Capacitor = {
            isNativePlatform: () => false,
            getPlatform: () => 'web',
          };
          export const App = {
            addListener: () => Promise.resolve({ remove: () => Promise.resolve() }),
            exitApp: () => {},
          };
          export const Haptics = {
            impact: () => Promise.resolve(),
            notification: () => Promise.resolve(),
            selectionChanged: () => Promise.resolve(),
            selectionStart: () => Promise.resolve(),
            selectionEnd: () => Promise.resolve(),
          };
          export const ImpactStyle = { Light: 'LIGHT', Medium: 'MEDIUM', Heavy: 'HEAVY' };
          export const NotificationType = { Success: 'SUCCESS', Warning: 'WARNING', Error: 'ERROR' };
          export const Preferences = {
            get: () => Promise.resolve({ value: null }),
            set: () => Promise.resolve(),
            remove: () => Promise.resolve(),
            clear: () => Promise.resolve(),
            keys: () => Promise.resolve({ keys: [] }),
          };
          export const KeepAwake = {
            keepAwake: () => Promise.resolve(),
            allowSleep: () => Promise.resolve(),
            isSupported: () => Promise.resolve({ isSupported: false }),
            isKeptAwake: () => Promise.resolve({ isKeptAwake: false }),
          };
          export default {};
        `
      }
      return null
    },
  }
}

// https://vite.dev/config/
export default defineConfig({
  base: './',
  plugins: [
    capacitorStubPlugin(),
    vue(),
  ],
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
