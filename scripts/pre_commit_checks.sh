#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_backend_pytest() {
  cd "$ROOT_DIR/backend"
  venv/bin/python -m pytest tests
}

run_flutter_test() {
  cd "$ROOT_DIR/flutter"
  flutter test \
    test/widget_test.dart \
    test/providers/workout_provider_test.dart \
    test/services/sync_service_test.dart \
    test/screens/workouts/my_workouts_screen_test.dart \
    test/screens/manual/manual_timer_screen_test.dart
}

run_flutter_analyze() {
  cd "$ROOT_DIR/flutter"
  flutter analyze --no-fatal-infos
}

case "${1:-all}" in
  backend_pytest)
    run_backend_pytest
    ;;
  flutter_test)
    run_flutter_test
    ;;
  flutter_analyze)
    run_flutter_analyze
    ;;
  all)
    run_backend_pytest
    run_flutter_test
    run_flutter_analyze
    ;;
  *)
    echo "Usage: scripts/pre_commit_checks.sh [backend_pytest|flutter_test|flutter_analyze|all]" >&2
    exit 1
    ;;
esac
