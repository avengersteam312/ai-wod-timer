# CI/CD Workflows

## Overview

| Workflow | Trigger | Purpose |
|---|---|---|
| `pr-check.yml` | Pull request | Lint + test gate before merge |
| `deploy-ios.yml` | Push to `master` | Build Flutter IPA → upload to TestFlight |
| `test-ios-signing.yml` | Manual | Validate signing secrets in ~1 min (no full build) |
| `sync-grafana-dashboard.yml` | Manual (auto disabled) | Push `ai_wod_timer.json` → Grafana Cloud |
| `export-grafana-dashboard.yml` | Manual | Pull live Grafana dashboard → open PR |

---

## iOS Deploy (`deploy-ios.yml`)

### How it works

The pipeline uses a **two-step codesign approach** to avoid a CocoaPods conflict:

1. **Flutter build + `xcodebuild archive`** — compiled with `CODE_SIGNING_ALLOWED=NO`. This avoids a failure where CocoaPods pods try to use a Development provisioning profile, which requires a physical device and is unavailable on CI.
2. **`xcodebuild -exportArchive`** — signs the archive with the App Store Distribution certificate and provisioning profile. Signing happens exactly once, at the right time, with the right identity.

### Required GitHub Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | What it is | How to generate |
|---|---|---|
| `DISTRIBUTION_CERTIFICATE_BASE64` | Apple Distribution `.p12` certificate, base64-encoded | See below |
| `DISTRIBUTION_CERTIFICATE_PASSWORD` | Password set when exporting the `.p12` | See below |
| `APP_STORE_CONNECT_API_KEY_BASE64` | `AuthKey_88R6NGQ7J4.p8` key file, base64-encoded | See below |
| `FLUTTER_SENTRY_DSN` | Sentry DSN for the Flutter project | Sentry → Flutter project → Settings → Client Keys (DSN) |
| `DISCORD_WEBHOOK_URL` | Discord channel webhook URL | Discord → channel settings → Integrations → Webhooks |

#### Exporting the Distribution Certificate

1. Open **Keychain Access** on macOS
2. Find `Apple Distribution: Nursultan Altynbek` (or similar)
3. Right-click → **Export** → save as `distribution.p12`, set a password
4. Base64-encode it:
   ```bash
   base64 -i distribution.p12 | pbcopy
   ```
5. Paste the output as `DISTRIBUTION_CERTIFICATE_BASE64`
6. Store the export password as `DISTRIBUTION_CERTIFICATE_PASSWORD`

#### Base64-encoding the App Store Connect API key

```bash
base64 -i ~/.appstoreconnect/private_keys/AuthKey_88R6NGQ7J4.p8 | pbcopy
```

Paste the output as `APP_STORE_CONNECT_API_KEY_BASE64`.

Credentials reference (never in code — stored in Apple Passwords app):
- Key ID: `88R6NGQ7J4`
- Issuer ID: `2e175de1-26c8-4f2e-91fb-2ece7aba0b12`
- Key file: `~/.appstoreconnect/private_keys/AuthKey_88R6NGQ7J4.p8`

### Provisioning profile install

`-allowProvisioningUpdates` only works with **automatic signing** and does nothing for manual signing. Instead, the workflow calls the App Store Connect API directly (using PyJWT) to download and physically install the provisioning profile into `~/Library/MobileDevice/Provisioning Profiles/` before the export step.

If a new profile is created in App Store Connect, it will be picked up automatically — no workflow changes needed.

### `camera_avfoundation` Xcode 16 patch

`AVCaptureSession.wasInterruptedNotification` and `.runtimeErrorNotification` were removed in iOS 18 SDK (Xcode 16). The `camera_avfoundation` plugin still references these deprecated APIs.

The workflow patches the plugin's Swift file at build time using `sed`. This is applied every run because the file lives in `~/.pub-cache` (the Flutter package cache) which is not persisted. The patch is idempotent.

**If `camera_avfoundation` is upgraded**, check whether the new version already handles this — if so, the patch step will silently no-op (the `sed` patterns won't match and the build succeeds).

### macOS runner version

`macos-15` is required — it ships with Xcode 16 which provides the iOS 18 SDK. Older runners (macOS 13/14 with Xcode 15) cannot build for iOS 18 targets.

### Build number

The build number is set to `GITHUB_RUN_NUMBER` (monotonically increasing per repo). The marketing version comes from `flutter/pubspec.yaml`. To bump the user-visible version (`1.0.0`, `1.1.0`, etc.) edit `pubspec.yaml` directly before merging.

### pip3 on macOS runners

macOS runners use a Homebrew-managed Python environment (PEP 668). Installing packages requires `--break-system-packages`:
```bash
pip3 install --quiet --break-system-packages requests pyjwt cryptography
```
Without this flag the step fails with `externally-managed-environment`.

---

## Signing Smoke Test (`test-ios-signing.yml`)

Run this **before** wiring any signing changes to the push trigger. It validates all four signing steps (cert import, API key, pip3 install, profile download) in ~1 minute without running a full Flutter build.

**When to run:**
- After rotating the distribution certificate
- After creating a new provisioning profile
- After updating any signing-related secrets
- When debugging a `deploy-ios` failure related to signing

Trigger: **Actions → Test iOS Signing (smoke test) → Run workflow**

---

## Grafana Dashboard CI

### Source of truth

`observability/provisioning/dashboards/ai_wod_timer.json` is the canonical dashboard. Grafana Cloud is kept in sync from this file — not the other way around.

### Required GitHub Secrets

| Secret | Value |
|---|---|
| `GRAFANA_URL` | `https://aiwodtimer.grafana.net` |
| `GRAFANA_SA_TOKEN` | Service account token — see `observability/SETUP_CHECKLIST.md` step 2e |

The service account needs `dashboards:write` for the sync workflow and `dashboards:read` for the export workflow.

### Sync workflow (`sync-grafana-dashboard.yml`)

Pushes the repo JSON to Grafana. Currently **`workflow_dispatch` only** — the automatic push trigger is disabled until the round-trip (export → PR → merge → sync) is validated.

To enable automatic sync on every merge, add to the `on:` block:
```yaml
push:
  branches: [master]
  paths:
    - 'observability/provisioning/dashboards/ai_wod_timer.json'
```

### Export workflow (`export-grafana-dashboard.yml`)

Pulls the live Grafana dashboard and opens a PR with the diff. Use this after making changes via the Grafana UI or MCP that you want to persist to the repo.

**Current known issue:** the export workflow returns HTTP 403 because the service account is missing `dashboards:read`. Fix: Grafana → Administration → Service accounts → select the account → add `dashboards:read` viewer role.

### Typical round-trip

```
Edit dashboard in Grafana UI
       ↓
Run export-grafana-dashboard workflow
       ↓
Review + merge the PR
       ↓
Run sync-grafana-dashboard workflow (confirms round-trip is clean)
```

---

## Certificate Renewal

Distribution certificates expire annually. When the cert expires:

1. In Xcode or developer.apple.com, create a new **Apple Distribution** certificate
2. Export it as a new `.p12` with a new password
3. Base64-encode and update both `DISTRIBUTION_CERTIFICATE_BASE64` and `DISTRIBUTION_CERTIFICATE_PASSWORD` in GitHub Secrets
4. Run the signing smoke test to verify before the next deploy

Provisioning profiles expire annually too. They auto-renew when the profile is regenerated in App Store Connect. The workflow fetches them fresh on every run, so no CI change is needed after renewal.
