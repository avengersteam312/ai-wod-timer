import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.wodtimer.app',
  appName: 'AI WOD Timer',
  webDir: 'dist',
  server: {
    // For development, you can set url to your local dev server
    // url: 'http://localhost:5173',
    // cleartext: true, // Allow HTTP for local dev (Android)
    androidScheme: 'https',
  },
  ios: {
    contentInset: 'automatic',
  },
  android: {
    allowMixedContent: false,
  },
};

export default config;
