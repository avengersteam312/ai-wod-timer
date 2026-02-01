/// <reference types="vite/client" />

/**
 * Build-time flag for Capacitor/native features.
 * Set VITE_NATIVE_BUILD=true when building for iOS/Android.
 * When false, Capacitor code is tree-shaken out.
 */
declare const __CAPACITOR_ENABLED__: boolean
