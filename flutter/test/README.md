# Flutter Testing Guide

This document covers the Flutter-side test layers in this repository, how to run them, and which ones are part of the fast pre-commit path.

## Test Layers

### 1. Fast unit and widget tests

Location:

- `flutter/test/`

Purpose:

- provider logic
- service behavior
- screen/widget rendering and interaction
- fast feedback during development

Command:

```bash
cd flutter
flutter test
```

Notes:

- This is the default lightweight Flutter test command.
- It does not replace the iOS simulator integration suite.

### 2. Deterministic integration tests

Location:

- `flutter/integration_test/ui_flow_test.dart`
- `flutter/integration_test/support/test_harness.dart`

Purpose:

- end-to-end Flutter UI flows with injected fakes and in-memory storage
- no real backend dependency
- no real Supabase sign-in requirement
- closest thing to a Playwright-style mobile flow suite, but deterministic

What is mocked or injected:

- authenticated test user via `AppTestHarness.buildUser()`
- fake API parse responses
- fake image picker
- fake storage
- fake video provider behavior

Command:

```bash
cd flutter
flutter test integration_test/ui_flow_test.dart -d 'iPhone 17 Pro'
```

### 3. Real smoke tests

Location:

- `flutter/integration_test/real_auth_smoke_test.dart`

Purpose:

- prove the real app can sign in with a real account
- prove at least one real backend-driven AI creation flow works
- verify save/delete behavior against the real app path

These tests use:

- the real app bootstrap from `lib/main.dart`
- real Supabase auth
- real backend text parse flow

These tests do not use the deterministic harness user.

Command:

```bash
cd flutter
flutter test integration_test/real_auth_smoke_test.dart \
  --dart-define-from-file=e2e.local.json \
  -d 'iPhone 17 Pro'
```

## Local Prerequisites

Before running any Flutter integration tests:

1. Install dependencies.

```bash
cd flutter
flutter pub get
```

2. Create `flutter/.env`.

```bash
cp .env.example .env
```

3. For real smoke tests only, create `flutter/e2e.local.json`.

```bash
cp e2e.local.example.json e2e.local.json
```

Example contents:

```json
{
  "E2E_TEST_EMAIL": "your-test-email@example.com",
  "E2E_TEST_PASSWORD": "your-test-password"
}
```

4. Boot an iOS simulator, or connect a device.

List devices:

```bash
cd flutter
flutter devices
```

Important:

- You do not need to run `flutter run` before integration tests.
- `flutter test integration_test ...` builds, installs, launches, and drives the app itself.
- If multiple devices are connected, always pass `-d <device-id-or-name>`.

## Run Commands

### Run all lightweight Flutter tests

```bash
cd flutter
flutter test
```

### Run the deterministic iOS UI flow suite

```bash
cd flutter
flutter test integration_test/ui_flow_test.dart -d 'iPhone 17 Pro'
```

### Run the real auth/backend smoke suite

```bash
cd flutter
flutter test integration_test/real_auth_smoke_test.dart \
  --dart-define-from-file=e2e.local.json \
  -d 'iPhone 17 Pro'
```

### Run all Flutter tests in this repo

```bash
cd flutter
flutter test
flutter test integration_test/ui_flow_test.dart -d 'iPhone 17 Pro'
flutter test integration_test/real_auth_smoke_test.dart \
  --dart-define-from-file=e2e.local.json \
  -d 'iPhone 17 Pro'
```

If you want one command for all integration tests together:

```bash
cd flutter
flutter test integration_test \
  --dart-define-from-file=e2e.local.json \
  -d 'iPhone 17 Pro'
```

Notes:

- `real_auth_smoke_test.dart` skips credentialed tests if `E2E_TEST_EMAIL` and `E2E_TEST_PASSWORD` are not provided.
- Running `flutter test integration_test ...` does not replace `flutter test`; run both if you want full Flutter coverage.

## Pre-commit and CI

### What runs in pre-commit

Configured in:

- `.pre-commit-config.yaml`
- `scripts/pre_commit_checks.sh`

Fast Flutter checks in pre-commit are:

- `flutter analyze --no-fatal-infos`
- a small fast subset of `flutter test`

Current pre-commit Flutter test subset:

- `test/widget_test.dart`
- `test/providers/workout_provider_test.dart`
- `test/services/sync_service_test.dart`
- `test/screens/workouts/my_workouts_screen_test.dart`
- `test/screens/manual/manual_timer_screen_test.dart`

What does not run in pre-commit:

- deterministic iOS integration tests
- real auth/backend smoke tests

### What runs in GitHub Actions

PR workflow:

- `.github/workflows/pr-check.yml`
- runs `flutter analyze`
- runs `flutter test`
- does not run the iOS simulator integration suite

Manual iOS workflow:

- `.github/workflows/ios-ui-tests.yml`
- manual only via `workflow_dispatch`
- boots an iOS simulator on macOS
- runs `flutter test integration_test ...`
- passes `E2E_TEST_EMAIL` and `E2E_TEST_PASSWORD` from GitHub secrets

## Which test type should I use?

Use fast unit/widget tests when:

- validating provider logic
- checking render states
- testing local component behavior

Use deterministic integration tests when:

- validating major app flows
- testing navigation and multi-screen state
- testing image-mode, save/delete, history, and video flows without backend flakiness

Use real smoke tests when:

- checking that auth really works
- checking that the real backend text creation flow still works
- verifying one or two high-value end-to-end paths against production-like services

## Current Rule Of Thumb

- Run `flutter test` often.
- Run `ui_flow_test.dart` before merging UI flow changes.
- Run `real_auth_smoke_test.dart` when touching auth, real AI creation, or saved-timer behavior.
- Keep most coverage deterministic; keep only a small number of real smoke tests.
