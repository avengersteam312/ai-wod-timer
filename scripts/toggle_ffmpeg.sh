#!/bin/bash
# Toggle FFmpeg Kit dependency for Flutter builds
# FFmpeg Kit doesn't support iOS simulator, so it must be disabled for simulator builds
#
# Usage:
#   ./scripts/toggle_ffmpeg.sh enable   # For device/production builds
#   ./scripts/toggle_ffmpeg.sh disable  # For simulator/development builds
#   ./scripts/toggle_ffmpeg.sh status   # Check current state

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
FLUTTER_DIR="$ROOT_DIR/flutter"
PUBSPEC="$FLUTTER_DIR/pubspec.yaml"
SERVICE="$FLUTTER_DIR/lib/services/ffmpeg_service.dart"
TEMPLATES_DIR="$SCRIPT_DIR/ffmpeg_templates"
SERVICE_STUB="$TEMPLATES_DIR/ffmpeg_service_stub.dart"
SERVICE_IMPL="$TEMPLATES_DIR/ffmpeg_service_impl.dart"

check_status() {
    if grep -q "^  ffmpeg_kit_flutter_new:" "$PUBSPEC" 2>/dev/null; then
        echo "FFmpeg is ENABLED"
        echo "  - pubspec.yaml: dependency uncommented"
        echo "  - Can build for: physical devices only"
        echo "  - Run with: flutter run -d <device>"
    else
        echo "FFmpeg is DISABLED"
        echo "  - pubspec.yaml: dependency commented"
        echo "  - Can build for: simulator and devices"
        echo "  - Run with: flutter run"
        echo "  - Note: Video overlay processing unavailable"
    fi
}

enable_ffmpeg() {
    echo "Enabling FFmpeg Kit..."

    # Enable in pubspec.yaml
    if grep -q "^  # ffmpeg_kit_flutter_new:" "$PUBSPEC"; then
        sed -i '' 's/^  # ffmpeg_kit_flutter_new:/  ffmpeg_kit_flutter_new:/' "$PUBSPEC"
        echo "  [pubspec.yaml] Enabled dependency"
    else
        echo "  [pubspec.yaml] Already enabled"
    fi

    # Copy impl template
    cp "$SERVICE_IMPL" "$SERVICE"
    echo "  [ffmpeg_service.dart] Using full implementation"

    echo ""
    echo "Cleaning build..."
    cd "$FLUTTER_DIR" && flutter clean

    echo ""
    echo "Running flutter pub get..."
    cd "$FLUTTER_DIR" && flutter pub get

    echo ""
    echo "Running pod install..."
    cd "$FLUTTER_DIR/ios" && pod install

    echo ""
    echo "FFmpeg enabled. Run with:"
    echo "  cd flutter && flutter run -d <device_id>"
}

disable_ffmpeg() {
    echo "Disabling FFmpeg Kit..."

    # Disable in pubspec.yaml
    if grep -q "^  ffmpeg_kit_flutter_new:" "$PUBSPEC"; then
        sed -i '' 's/^  ffmpeg_kit_flutter_new:/  # ffmpeg_kit_flutter_new:/' "$PUBSPEC"
        echo "  [pubspec.yaml] Disabled dependency"
    else
        echo "  [pubspec.yaml] Already disabled"
    fi

    # Copy stub template
    cp "$SERVICE_STUB" "$SERVICE"
    echo "  [ffmpeg_service.dart] Using stub implementation"

    echo ""
    echo "Cleaning build..."
    cd "$FLUTTER_DIR" && flutter clean

    echo ""
    echo "Running flutter pub get..."
    cd "$FLUTTER_DIR" && flutter pub get

    echo ""
    echo "Running pod install..."
    cd "$FLUTTER_DIR/ios" && pod install

    echo ""
    echo "FFmpeg disabled. Run with:"
    echo "  cd flutter && flutter run"
}

case "${1:-status}" in
    enable|on|1)
        enable_ffmpeg
        ;;
    disable|off|0)
        disable_ffmpeg
        ;;
    status|check)
        check_status
        ;;
    *)
        echo "Usage: $0 {enable|disable|status}"
        echo ""
        echo "Commands:"
        echo "  enable   - Enable FFmpeg for device/production builds"
        echo "  disable  - Disable FFmpeg for simulator/development builds"
        echo "  status   - Show current FFmpeg state"
        exit 1
        ;;
esac
