# PRD: Capacitor Integration

## Overview

Add Capacitor to enable native iOS and Android builds with offline support, native audio, haptic feedback, and app store distribution.

## Goals

- Enable building native iOS and Android apps from the existing Vue web app
- Add native mobile features: haptics, keep-awake, preferences storage
- Handle platform-specific UX (safe areas, back button)
- Maintain web compatibility

## Non-Goals

- Push notifications (future iteration)
- Background audio playback (future iteration)
- App store submission process (separate task)

---

## User Stories

### Phase 1: Core Setup

#### US-001: Install Capacitor Core Packages
**Priority:** 1

As a developer, I need Capacitor installed in the project to enable native mobile builds.

**Acceptance Criteria:**
- Install `@capacitor/core` and `@capacitor/cli` as dependencies in frontend
- Install `@capacitor/ios` and `@capacitor/android` as dependencies
- Typecheck passes

---

#### US-002: Initialize Capacitor Configuration
**Priority:** 2

As a developer, I need Capacitor configured with proper app metadata.

**Acceptance Criteria:**
- Run `npx cap init` with appId `com.wodtimer.app` and appName `AI WOD Timer`
- Create `capacitor.config.ts` in frontend root
- Set `webDir` to `dist` (Vite build output)
- Configure `server.url` for dev mode with proper localhost handling
- Typecheck passes

---

#### US-003: Add iOS Platform
**Priority:** 3

As a developer, I need the iOS native project scaffolded.

**Acceptance Criteria:**
- Run `npx cap add ios` to create `ios/` directory
- Verify `ios/App` folder structure exists
- Add `ios/` to `.gitignore` with exceptions for config files
- Typecheck passes

---

#### US-004: Add Android Platform
**Priority:** 4

As a developer, I need the Android native project scaffolded.

**Acceptance Criteria:**
- Run `npx cap add android` to create `android/` directory
- Verify `android/app` folder structure exists
- Add `android/` to `.gitignore` with exceptions for config files
- Typecheck passes

---

#### US-005: Update Vite Config for Capacitor Compatibility
**Priority:** 5

As a developer, I need Vite configured to work properly with Capacitor.

**Acceptance Criteria:**
- Update `vite.config.ts` base to `'./'` for relative asset paths
- Ensure build output is compatible with Capacitor webview
- Add build script that runs `vite build && cap sync`
- Typecheck passes

---

### Phase 2: Native Plugins

#### US-006: Install and Configure Capacitor Preferences Plugin
**Priority:** 6

As a user, I want my preferences persisted natively on mobile devices.

**Acceptance Criteria:**
- Install `@capacitor/preferences` plugin
- Create `src/services/capacitorStorage.ts` wrapper
- Implement `get`, `set`, `remove` methods matching localStorage API
- Detect Capacitor native vs web and use appropriate storage
- Typecheck passes

---

#### US-007: Install and Configure Capacitor Haptics Plugin
**Priority:** 7

As a user, I want haptic feedback during workouts for better awareness.

**Acceptance Criteria:**
- Install `@capacitor/haptics` plugin
- Create `src/composables/useHaptics.ts` wrapper
- Implement vibrate functions: light, medium, heavy, success, warning, error
- Gracefully degrade on web (no-op)
- Typecheck passes

---

#### US-008: Install and Configure Capacitor KeepAwake Plugin
**Priority:** 8

As a user, I want the screen to stay on during active workouts.

**Acceptance Criteria:**
- Install `@capacitor-community/keep-awake` plugin
- Create `src/composables/useKeepAwake.ts` wrapper
- Implement `keepAwake` and `allowSleep` functions
- Enable keep awake when timer is running, disable when paused/stopped
- Typecheck passes

---

### Phase 3: Integration

#### US-009: Integrate Haptics into Timer Controls
**Priority:** 9

As a user, I want haptic feedback when interacting with timer controls.

**Acceptance Criteria:**
- Add light haptic on play/pause button press
- Add medium haptic on timer reset
- Add success haptic on workout completion
- Add warning haptic on final countdown (10, 5, 3, 2, 1)
- Typecheck passes

---

#### US-010: Integrate Keep Awake into Timer
**Priority:** 10

As a user, I want my screen to stay on while workout is active.

**Acceptance Criteria:**
- Call `keepAwake` when timer starts playing
- Call `allowSleep` when timer is paused, reset, or completed
- Handle component unmount to ensure screen sleep is restored
- Typecheck passes

---

#### US-011: Create Capacitor Platform Detection Utility
**Priority:** 11

As a developer, I need to detect the current platform for conditional logic.

**Acceptance Criteria:**
- Create `src/utils/platform.ts` with platform detection functions
- Implement `isNative()`, `isIOS()`, `isAndroid()`, `isWeb()`
- Use `Capacitor.isNativePlatform()` for detection
- Export platform constant for reactive usage
- Typecheck passes

---

### Phase 4: Platform-Specific UX

#### US-012: Configure iOS Safe Area Handling
**Priority:** 12

As a user, I want the app to respect iOS notch and home indicator.

**Acceptance Criteria:**
- Update `index.html` with `viewport-fit=cover` meta tag
- Apply `env(safe-area-inset-*)` CSS variables to layout components
- Ensure header respects `safe-area-inset-top`
- Ensure bottom nav respects `safe-area-inset-bottom`
- Typecheck passes

---

#### US-013: Configure Android Back Button Handling
**Priority:** 13

As a user, I want the Android back button to work correctly.

**Acceptance Criteria:**
- Install `@capacitor/app` plugin
- Listen for `backButton` event in `App.vue`
- Navigate back in router if history exists
- Show exit confirmation if on root route
- Typecheck passes

---

### Phase 5: Developer Experience

#### US-014: Add Capacitor NPM Scripts
**Priority:** 14

As a developer, I want convenient scripts to build and sync the app.

**Acceptance Criteria:**
- Add `cap:sync` script: `cap sync`
- Add `cap:ios` script: `cap open ios`
- Add `cap:android` script: `cap open android`
- Add `build:mobile` script: `npm run build && cap sync`
- Typecheck passes

---

#### US-015: Document Capacitor Build and Deployment Process
**Priority:** 15

As a developer, I need documentation for building and deploying the mobile apps.

**Acceptance Criteria:**
- Create `docs/capacitor-setup.md` with prerequisites
- Document iOS build process (requires Xcode)
- Document Android build process (requires Android Studio)
- Document signing and release build instructions
- Include troubleshooting section for common issues

---

## Technical Notes

### Dependencies to Add
```json
{
  "@capacitor/core": "^6.x",
  "@capacitor/cli": "^6.x",
  "@capacitor/ios": "^6.x",
  "@capacitor/android": "^6.x",
  "@capacitor/preferences": "^6.x",
  "@capacitor/haptics": "^6.x",
  "@capacitor/app": "^6.x",
  "@capacitor-community/keep-awake": "^5.x"
}
```

### File Structure
```
frontend/
├── capacitor.config.ts    # Capacitor configuration
├── ios/                   # iOS native project (gitignored)
├── android/               # Android native project (gitignored)
└── src/
    ├── composables/
    │   ├── useHaptics.ts
    │   └── useKeepAwake.ts
    ├── services/
    │   └── capacitorStorage.ts
    └── utils/
        └── platform.ts
```

### Build Commands
```bash
npm run build:mobile   # Build web + sync to native
npm run cap:ios        # Open in Xcode
npm run cap:android    # Open in Android Studio
```
