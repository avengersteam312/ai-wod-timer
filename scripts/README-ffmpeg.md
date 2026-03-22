# FFmpeg Toggle for Flutter

FFmpeg Kit is used for baking timer overlays into recorded workout videos. However, **FFmpeg Kit doesn't support iOS Simulator** — it only ships ARM binaries for physical devices.

This script manages FFmpeg availability across development and production builds.

## Quick Reference

| Environment | FFmpeg | Command |
|-------------|--------|---------|
| Simulator (dev) | Disabled | `flutter run` |
| Physical device | Enabled | `./scripts/toggle_ffmpeg.sh enable` then `flutter run -d <device> --dart-define=FFMPEG_ENABLED=true` |
| Production (CI) | Enabled | Automatic via `deploy-ios.yml` |

## How It Works

The toggle script manages two things:

1. **pubspec.yaml** — comments/uncomments the `ffmpeg_kit_flutter_new` dependency
2. **ffmpeg_service.dart** — comments/uncomments the FFmpeg imports

When disabled, `FFmpegService.isAvailable` returns `false` and all methods gracefully return `null`.

## Commands

```bash
# Check current state
./scripts/toggle_ffmpeg.sh status

# Enable for device/production builds
./scripts/toggle_ffmpeg.sh enable

# Disable for simulator builds (default)
./scripts/toggle_ffmpeg.sh disable
```

## Development Workflow

### Running on Simulator (default)

FFmpeg is disabled by default. Just run:

```bash
cd flutter
flutter run
```

Video recording works, but overlay processing returns the original video without the timer baked in.

### Testing on Physical Device

```bash
# 1. Enable FFmpeg
./scripts/toggle_ffmpeg.sh enable

# 2. Run with dart-define flag
cd flutter
flutter run -d <device_id> --dart-define=FFMPEG_ENABLED=true
```

### Switching Back to Simulator

```bash
./scripts/toggle_ffmpeg.sh disable
cd flutter
flutter run
```

## CI/Production

The `deploy-ios.yml` workflow automatically:

1. Runs `./scripts/toggle_ffmpeg.sh enable`
2. Builds with `--dart-define=FFMPEG_ENABLED=true`

No manual intervention needed for App Store builds.

## Why This Approach?

FFmpeg Kit is a pre-compiled native framework. Unlike source-based pods, it can't be conditionally compiled for different architectures. The only way to support both simulator and device builds from the same codebase is to toggle the dependency itself.

The `--dart-define=FFMPEG_ENABLED=true` flag provides a runtime check so the Dart code knows whether FFmpeg is actually available, even though the native code presence is determined at build time.
