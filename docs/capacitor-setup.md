# Capacitor Setup Guide

This guide covers building and deploying AI WOD Timer as native iOS and Android apps using Capacitor.

## Prerequisites

### General
- Node.js 18+ and npm
- Frontend dependencies installed (`cd frontend && npm install`)

### iOS Development
- macOS (required for iOS builds)
- Xcode 15+ with command line tools
- Apple Developer account (for device testing and App Store distribution)
- CocoaPods (`sudo gem install cocoapods`)

### Android Development
- Android Studio (latest stable version)
- Android SDK with platform tools
- JDK 17+ (included with Android Studio)
- An Android device or emulator

## Project Structure

```
frontend/
├── capacitor.config.ts    # Capacitor configuration
├── ios/                   # iOS native project (Xcode)
│   └── App/
│       ├── App/           # iOS app source
│       └── App.xcodeproj  # Xcode project
└── android/               # Android native project
    └── app/               # Android app module
        └── src/main/
```

## Development Workflow

### 1. Build Web Assets

Before syncing to native platforms, build the web assets:

```bash
cd frontend
npm run build
```

### 2. Sync to Native Platforms

Sync web assets and plugins to iOS and Android:

```bash
npm run cap:sync
# or
npx cap sync
```

### 3. Build and Run

#### Combined Build + Sync

For a complete build and sync in one command:

```bash
npm run build:mobile
```

## iOS Build Process

### Open in Xcode

```bash
npm run cap:ios
# or
npx cap open ios
```

### Development Build

1. In Xcode, select your target device or simulator
2. Click **Run** (▶) or press `Cmd + R`
3. The app will build and launch on the selected device

### Device Testing

1. Connect your iOS device via USB
2. In Xcode: **Window → Devices and Simulators** - verify device appears
3. On your device: **Settings → General → Device Management** - trust your developer certificate
4. Select your device in Xcode and run

### Signing Configuration

1. In Xcode, select the **App** project in the navigator
2. Select the **App** target
3. Go to **Signing & Capabilities** tab
4. Enable **Automatically manage signing**
5. Select your team (Apple Developer account)
6. Xcode will create provisioning profiles automatically

### Release Build (App Store)

1. In Xcode: **Product → Archive**
2. Wait for archive to complete
3. In the Archives organizer, select the archive
4. Click **Distribute App**
5. Select **App Store Connect** and follow the wizard
6. Upload to App Store Connect for TestFlight or release

## Android Build Process

### Open in Android Studio

```bash
npm run cap:android
# or
npx cap open android
```

### Development Build

1. In Android Studio, wait for Gradle sync to complete
2. Select a device or emulator from the device dropdown
3. Click **Run** (▶) or press `Shift + F10`

### Device Testing

1. Enable **Developer Options** on your Android device:
   - **Settings → About Phone** - tap **Build Number** 7 times
2. Enable **USB Debugging**:
   - **Settings → Developer Options → USB Debugging**
3. Connect device via USB and accept the debugging prompt
4. Device should appear in Android Studio's device dropdown

### Signing Configuration

#### Debug Builds
Debug builds use an auto-generated debug keystore - no configuration needed.

#### Release Builds

1. Generate a keystore (one-time):
```bash
keytool -genkey -v -keystore release-key.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias my-key-alias
```

2. Create `frontend/android/keystore.properties`:
```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=my-key-alias
storeFile=../release-key.jks
```

3. Update `frontend/android/app/build.gradle` to use the keystore (see Android docs for full configuration)

### Release Build (Play Store)

1. In Android Studio: **Build → Generate Signed Bundle / APK**
2. Select **Android App Bundle** (recommended for Play Store)
3. Select your keystore and enter credentials
4. Select **release** build variant
5. Click **Create** - AAB will be generated in `app/release/`
6. Upload the `.aab` file to Google Play Console

## Live Reload (Development)

For faster development with live reload on device:

1. Update `frontend/capacitor.config.ts`:
```typescript
const config: CapacitorConfig = {
  // ... other config
  server: {
    url: 'http://YOUR_LOCAL_IP:5173',  // e.g., http://192.168.1.100:5173
    cleartext: true,  // Required for Android HTTP
  },
};
```

2. Start the dev server:
```bash
npm run dev -- --host
```

3. Sync and run on device:
```bash
npm run cap:sync
npm run cap:ios  # or cap:android
```

4. **Important**: Remove or comment out the `url` setting before building for production.

## App Configuration

### App ID and Name

Configured in `frontend/capacitor.config.ts`:
- **App ID**: `com.wodtimer.app`
- **App Name**: `AI WOD Timer`

To change these:
1. Update `capacitor.config.ts`
2. For iOS: Update Bundle Identifier in Xcode
3. For Android: Update `applicationId` in `android/app/build.gradle`

### App Icons and Splash Screens

#### iOS
Replace images in `ios/App/App/Assets.xcassets/`:
- `AppIcon.appiconset/` - App icons (various sizes)
- Create a `Splash.imageset/` for splash screens

#### Android
Replace images in `android/app/src/main/res/`:
- `mipmap-*/` folders - App icons (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi)
- `drawable/` - Splash screen

Use tools like [capacitor-assets](https://github.com/ionic-team/capacitor-assets) or App Icon Generator websites to create all required sizes.

## Installed Capacitor Plugins

| Plugin | Package | Purpose |
|--------|---------|---------|
| Core | `@capacitor/core` | Capacitor runtime |
| CLI | `@capacitor/cli` | Build and sync commands |
| iOS | `@capacitor/ios` | iOS platform support |
| Android | `@capacitor/android` | Android platform support |
| App | `@capacitor/app` | App lifecycle, back button |
| Preferences | `@capacitor/preferences` | Native key-value storage |
| Haptics | `@capacitor/haptics` | Vibration feedback |
| Keep Awake | `@capacitor-community/keep-awake` | Prevent screen sleep |

## npm Scripts Reference

| Script | Command | Description |
|--------|---------|-------------|
| `build:mobile` | `npm run build && cap sync` | Build web + sync to native |
| `cap:sync` | `cap sync` | Sync web assets to native |
| `cap:ios` | `cap open ios` | Open iOS project in Xcode |
| `cap:android` | `cap open android` | Open Android project in Android Studio |

## Troubleshooting

### iOS

#### "No provisioning profile"
- Ensure you're signed into an Apple Developer account in Xcode
- Enable **Automatically manage signing** in target settings
- Check that your device is registered in your developer portal

#### Pods not found
```bash
cd frontend/ios/App
pod install
```

#### Build fails after plugin changes
```bash
npm run cap:sync
cd frontend/ios/App && pod install --repo-update
```

### Android

#### Gradle sync failed
- **File → Sync Project with Gradle Files**
- Check that Android SDK is properly configured
- Invalidate caches: **File → Invalidate Caches / Restart**

#### "SDK location not found"
Create `frontend/android/local.properties`:
```properties
sdk.dir=/Users/YOUR_USERNAME/Library/Android/sdk
```

#### App not installing on device
- Check USB debugging is enabled
- Accept USB debugging prompt on device
- Try a different USB cable or port

### General

#### Web content not updating
```bash
npm run build
npm run cap:sync
```

#### Plugin not working on native
1. Verify plugin is installed: `npm list @capacitor/PLUGIN_NAME`
2. Sync plugins: `npm run cap:sync`
3. For iOS: Run `pod install` in `ios/App/`
4. Rebuild the native project

#### Safe area issues on iOS
- Ensure `viewport-fit=cover` is in `index.html`
- Use `safe-area-*` CSS classes on headers/footers
- Check `env(safe-area-inset-*)` CSS variables

## Resources

- [Capacitor Documentation](https://capacitorjs.com/docs)
- [Capacitor iOS Docs](https://capacitorjs.com/docs/ios)
- [Capacitor Android Docs](https://capacitorjs.com/docs/android)
- [App Store Connect](https://appstoreconnect.apple.com)
- [Google Play Console](https://play.google.com/console)
