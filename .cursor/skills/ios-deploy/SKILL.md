---
name: ios-deploy
description: "Deploy a new version of the Flutter iOS app to App Store Connect. Bumps version, builds, archives, exports IPA, and uploads. Assumes first-time setup is already complete (/ios-setup). Triggers on: deploy ios, release ios, upload to app store, new ios build, ios release, bump version ios, ship ios."
---

# iOS App Store — Deploy New Version

Build, archive, and upload a new version to App Store Connect. Prerequisites: `/ios-setup` completed, Apple Developer Program active, API key configured.

## Invocation

`/ios-deploy [version] [build-number]`

**Examples:**
```
/ios-deploy              # interactive — asks for version info
/ios-deploy 1.1.0 2     # version 1.1.0, build number 2
```

---

## Step 0: Pre-flight Checks

```bash
# Verify workspace and credentials
ls flutter/ios/Runner.xcworkspace
ls ~/.appstoreconnect/private_keys/AuthKey_*.p8
ls flutter/ios/ExportOptions.plist

# Show current version
grep "^version:" flutter/pubspec.yaml

# Verify Xcode
xcodebuild -version
```

**Blockers — stop and inform user:**
- `~/.appstoreconnect/private_keys/AuthKey_*.p8` missing → run `/ios-setup` first or copy the key
- `flutter/ios/ExportOptions.plist` missing → run `/ios-setup` first
- `Runner.xcworkspace` missing → run `flutter pub get` then `flutter build ios --no-codesign`

---

## Step 1: Determine Version

If not provided as arguments, show the current version and ask:

```
Current version: {current_version} (build {current_build})

What should the new version be?
  A. Patch bump — bug fixes only       ({major}.{minor}.{patch+1}+{build+1})
  B. Minor bump — new features         ({major}.{minor+1}.0+{build+1})
  C. Major bump — breaking changes     ({major+1}.0.0+{build+1})
  D. Custom — I'll specify manually

(Build number always increments)
```

Version format in Flutter: `{version}+{build_number}` (e.g., `1.1.0+2`)

---

## Step 2: Bump Version in pubspec.yaml

Edit `flutter/pubspec.yaml` — update the `version` field:

```yaml
version: {NEW_VERSION}+{NEW_BUILD_NUMBER}
```

Verify:
```bash
grep "^version:" flutter/pubspec.yaml
```

---

## Step 3: Build Flutter Release

```bash
cd flutter && flutter build ios --release --no-codesign 2>&1
```

Expected: `✓ Built build/ios/iphoneos/Runner.app`

If this fails, show the full error and stop. Common fixes:
- `flutter pub get` if packages are out of date
- Check Dart compile errors

---

## Step 4: Archive (No Codesign)

Clean previous archive first, then archive:

```bash
rm -rf flutter/build/Runner.xcarchive flutter/build/ipa

xcodebuild \
  -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath ../build/Runner.xcarchive \
  archive \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | grep -E "error:|ARCHIVE|SUCCEEDED|FAILED"
```

Expected: `** ARCHIVE SUCCEEDED **`

> `CODE_SIGNING_ALLOWED=NO` skips Development profile creation (which requires registered devices). Distribution signing happens during export.

---

## Step 5: Export IPA

```bash
xcodebuild \
  -exportArchive \
  -archivePath flutter/build/Runner.xcarchive \
  -exportPath flutter/build/ipa \
  -exportOptionsPlist flutter/ios/ExportOptions.plist \
  -allowProvisioningUpdates \
  2>&1 | tail -10
```

Expected: `** EXPORT SUCCEEDED **`

Verify IPA size looks reasonable:
```bash
ls -lh flutter/build/ipa/*.ipa
```

---

## Step 6: Upload to App Store Connect

Detect API key details:

```bash
ls ~/.appstoreconnect/private_keys/AuthKey_*.p8
# Key ID is in the filename: AuthKey_{KEY_ID}.p8
```

If multiple keys exist, ask the user which to use.

Upload:

```bash
xcrun altool --upload-app \
  --type ios \
  --file flutter/build/ipa/ai_wod_timer.ipa \
  --apiKey {KEY_ID} \
  --apiIssuer {ISSUER_ID} \
  2>&1
```

Expected: `UPLOAD SUCCEEDED with no errors`

---

## Step 7: Confirm & Report

On success, print:

```
✅ iOS deploy complete!

Version:      {NEW_VERSION} (build {NEW_BUILD_NUMBER})
Bundle ID:    {BUNDLE_ID}
IPA size:     {SIZE}
Delivery UUID: {UUID from upload output}

Processing takes ~15–30 min. You'll get an email when done.

Next steps:
  • App Store Connect → My Apps → TestFlight → select the build → test it
  • To submit for App Store review:
    App Store tab → + Version → select build → fill metadata → Submit for Review
```

---

## Troubleshooting Reference

| Error | Cause | Fix |
|-------|-------|-----|
| `ARCHIVE FAILED` with `No profiles` | Development profile needed, no devices registered | Ensure `CODE_SIGNING_ALLOWED=NO` is passed (Step 4) |
| `EXPORT FAILED` with `no identity` | No Distribution certificate | Open Xcode → Settings → Accounts → Manage Certificates → + Apple Distribution |
| `AuthKey file not found` | Wrong key location | Copy `.p8` to `~/.appstoreconnect/private_keys/` |
| `Cannot determine the Apple ID from Bundle ID` | App doesn't exist in App Store Connect | Create it: appstoreconnect.apple.com → My Apps → + |
| `conflicting provisioning` on Pod targets | Podfile missing signing-disable hook | Check `flutter/ios/Podfile` has `CODE_SIGNING_ALLOWED = 'NO'` in `post_install`; run `pod install` |
| Upload fails with `authentication error` | API key permissions | Key needs App Manager or Admin role in App Store Connect |
| `Version already exists` | Build number already used | Increment build number in `pubspec.yaml` and retry from Step 3 |
