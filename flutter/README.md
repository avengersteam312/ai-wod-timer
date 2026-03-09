# AI WOD Timer

AI-powered workout timer app with cross-platform support.

## Prerequisites

- Flutter SDK >= 3.0.0
- Dart SDK (included with Flutter)
- For iOS: Xcode and CocoaPods
- For Android: Android Studio and Android SDK
- For macOS/Linux/Windows: respective platform toolchains

## Setup

### 1. Install Dependencies

```bash
cd flutter
flutter pub get
```

### 2. Configure Environment Variables

Copy the example environment file and fill in your values:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
API_BASE_URL=http://localhost:8000
AUTH_ENABLED=true
DEEP_LINK_SCHEME=com.aiwodtimer.app
```

The backend parse endpoints require a valid Supabase session, so `AUTH_ENABLED` should stay enabled in normal development and production.

### 3. Configure the Backend

The Flutter app calls authenticated backend parse endpoints. Create `backend/.env` and set at minimum:

```bash
cd ../backend
cp .env.example .env
```

```env
OPENAI_API_KEY=your-openai-api-key
SUPABASE_JWT_SECRET=your-supabase-jwt-secret
```

### 4. Generate Hive Adapters (if needed)

```bash
flutter pub run build_runner build
```

## Running the App

### iOS Simulator

```bash
flutter run -d ios
```

### Android Emulator

```bash
flutter run -d android
```

### macOS

```bash
flutter run -d macos
```

### Web

```bash
flutter run -d chrome
```

### List Available Devices

```bash
flutter devices
```

## Development Commands

### Run with Hot Reload

```bash
flutter run
```

### Build Release APK (Android)

```bash
flutter build apk --release
```

### Build Release IPA (iOS)

```bash
flutter build ipa --release
```

### Run Tests

```bash
flutter test
```

### Analyze Code

```bash
flutter analyze
```

## Project Structure

```
lib/           - Main application code
assets/        - Static assets (sounds, images)
  sounds/
    beeps/     - Timer beep sounds
    voice/     - Voice announcements
  images/      - App images
android/       - Android platform code
ios/           - iOS platform code
macos/         - macOS platform code
web/           - Web platform code
linux/         - Linux platform code
windows/       - Windows platform code
```

## Key Dependencies

- **provider** - State management
- **supabase_flutter** - Backend integration
- **audioplayers** - Audio playback for timer sounds
- **hive** - Local database for offline support
- **wakelock_plus** - Keep screen awake during workouts
