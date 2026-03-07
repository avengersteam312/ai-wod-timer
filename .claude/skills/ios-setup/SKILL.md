---
name: ios-setup
description: "First-time iOS App Store deployment setup for the Flutter app. Configures bundle ID, team ID, app display name, Podfile signing, ExportOptions.plist, builds the IPA, and uploads to App Store Connect. Use when deploying to the App Store for the first time or setting up a fresh environment. Triggers on: first ios deploy, setup ios deployment, ios app store setup, configure ios signing, first time app store."
argument-hint: "[bundle-id] [team-id] [app-display-name]"
allowed-tools: Bash, Read, Edit, Glob, Grep, AskUserQuestion
# consumers:
#   - standalone: yes — users invoke via /ios-setup
#   - auto-trigger: yes — when user asks about first-time iOS App Store deployment
#   - subagent: no
#   - cross-skill: yes — /ios-deploy depends on this being done first
---

# iOS App Store — First-Time Setup & Deploy

Complete first-time setup: configure project identifiers, fix CocoaPods signing conflicts, build the archive, and upload to App Store Connect.

## Invocation

`/ios-setup [bundle-id] [team-id] [app-display-name]`

**Examples:**
```
/ios-setup                                          # interactive — asks for all values
/ios-setup com.aiwodtimer.app X4J5J2543A "AI WOD Timer"
```

---

## Step 0: Gather Required Values

If not provided as arguments, ask the user for:

| Value | Where to find it | Example |
|-------|-----------------|---------|
| **Bundle ID** | Chosen by you (reverse-domain format) | `com.aiwodtimer.app` |
| **Team ID** | developer.apple.com → Account → Membership | `X4J5J2543A` |
| **App Display Name** | What users see on their home screen | `AI WOD Timer` |
| **Apple ID email** | Your Apple Developer account email | `dev@example.com` |
| **App Store Connect API Key (.p8 path)** | App Store Connect → Users & Access → Integrations → App Store Connect API | `~/Downloads/AuthKey_XXXXXXXX.p8` |
| **Key ID** | Shown on the API key page (also in filename) | `88R6NGQ7J4` |
| **Issuer ID** | Shown on the API key page (UUID format) | `2e175de1-...` |

Ask as a numbered list with current values pre-filled if detectable from the project.

---

## Step 1: Pre-flight Checks

```bash
# Verify Xcode CLI tools
xcode-select -p
xcodebuild -version

# Verify Flutter
flutter --version

# Verify workspace exists
ls flutter/ios/Runner.xcworkspace

# Check for existing bundle ID and team
grep "PRODUCT_BUNDLE_IDENTIFIER\|DEVELOPMENT_TEAM" flutter/ios/Runner.xcodeproj/project.pbxproj | grep -v RunnerTests | grep -v Pods
```

**Blockers — stop and inform user:**
- Xcode not installed
- Flutter not installed
- `flutter/ios/Runner.xcworkspace` missing (run `flutter pub get` then `cd flutter && flutter build ios --no-codesign` first)
- Apple Developer Program not active (paid membership required — $99/year at developer.apple.com)

---

## Step 2: Update Project Identifiers

### 2a. Bundle ID

```bash
# Replace in all Runner configurations (skip RunnerTests)
sed -i '' 's/PRODUCT_BUNDLE_IDENTIFIER = [^;]*;/PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};/' \
  flutter/ios/Runner.xcodeproj/project.pbxproj

# Verify — should show 3 Runner lines, not RunnerTests
grep -n "PRODUCT_BUNDLE_IDENTIFIER" flutter/ios/Runner.xcodeproj/project.pbxproj
```

> Only replace lines that were for the Runner target (not RunnerTests). The RunnerTests bundle ID (`com.example.aiWodTimer.RunnerTests`) can remain unchanged.

### 2b. Development Team ID

```bash
sed -i '' 's/DEVELOPMENT_TEAM = [A-Z0-9]*/DEVELOPMENT_TEAM = {TEAM_ID}/g' \
  flutter/ios/Runner.xcodeproj/project.pbxproj

grep -n "DEVELOPMENT_TEAM" flutter/ios/Runner.xcodeproj/project.pbxproj
```

### 2c. App Display Name

```bash
# Update CFBundleDisplayName in Info.plist
# Read current value first, then replace
grep -A1 "CFBundleDisplayName" flutter/ios/Runner/Info.plist
```

Edit `flutter/ios/Runner/Info.plist` — set `CFBundleDisplayName` to the desired display name.

---

## Step 3: Fix CocoaPods Signing Conflict

Without this, archiving with `CODE_SIGNING_ALLOWED=NO` still causes Pod targets to conflict.

Edit `flutter/ios/Podfile` — add signing-disable lines inside the `post_install` block:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
      config.build_settings['CODE_SIGN_IDENTITY'] = ''
    end
  end
end
```

Then re-run pod install from `flutter/ios/`:

```bash
cd flutter/ios && pod install
```

---

## Step 4: Create ExportOptions.plist

Write `flutter/ios/ExportOptions.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>teamID</key>
  <string>{TEAM_ID}</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>uploadBitcode</key>
  <false/>
  <key>compileBitcode</key>
  <false/>
  <key>uploadSymbols</key>
  <true/>
  <key>destination</key>
  <string>export</string>
</dict>
</plist>
```

---

## Step 5: Apple Developer Portal Setup

Instruct the user to complete these **manual steps** before continuing:

```
⚠️  Manual steps required on Apple Developer Portal:

1. Register the App ID:
   developer.apple.com → Certificates, Identifiers & Profiles
   → Identifiers → + → App ID → App
   → Bundle ID: {BUNDLE_ID}
   → Enable any capabilities needed (Push Notifications, etc.)
   → Register

2. Verify your Apple Developer Program membership is active:
   developer.apple.com → Account → Membership
   Status must be: Active

3. Sign in to Xcode with the Apple ID for team {TEAM_ID}:
   Xcode → Settings (⌘,) → Accounts → + → Apple ID

4. Create the app in App Store Connect:
   appstoreconnect.apple.com → My Apps → + → New App
   → Platform: iOS
   → Name: {APP_DISPLAY_NAME}
   → Bundle ID: {BUNDLE_ID}
   → SKU: (any unique string, e.g. aiwodtimer)
   → Create

Reply "done" when all 4 steps are complete.
```

---

## Step 6: Build Flutter Release

```bash
cd flutter && flutter build ios --release --no-codesign 2>&1
```

Expected: `✓ Built build/ios/iphoneos/Runner.app`

**If this fails:**
- Run `flutter pub get` first, then retry
- Check for compile errors in Dart code

---

## Step 7: Archive (No Codesign)

Run from `flutter/ios/`:

```bash
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

> Why `CODE_SIGNING_ALLOWED=NO`? Automatic signing requires registered devices to create a Development profile. This skips Development signing during archive; Distribution signing is applied in the export step instead.

---

## Step 8: Export IPA (App Store Distribution)

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

Verify the IPA exists:

```bash
ls -lh flutter/build/ipa/*.ipa
```

---

## Step 9: Upload to App Store Connect

### Setup API key (one-time)

```bash
mkdir -p ~/.appstoreconnect/private_keys
cp {P8_KEY_PATH} ~/.appstoreconnect/private_keys/
```

### Upload

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

## Step 10: Post-Upload

Tell the user:

```
✅ Upload complete!

Build is now processing on Apple's servers (~15–30 min).
You'll receive an email when processing finishes.

Next steps:
  1. App Store Connect → My Apps → {APP_NAME} → TestFlight
     → The build will appear when processing is done
  2. To submit for review:
     App Store tab → select build → add screenshots/description → Submit for Review
  3. For future deployments, use: /ios-deploy
```

---

## Troubleshooting Reference

| Error | Cause | Fix |
|-------|-------|-----|
| `No Account for Team` | Apple ID not signed in to Xcode | Xcode → Settings → Accounts → Add Apple ID |
| `No profiles for '...' were found` | App ID not registered | Register at developer.apple.com → Identifiers |
| `Communication with Apple failed: no devices` | Trying to create Development profile | Use `CODE_SIGNING_ALLOWED=NO` during archive (Step 7) |
| `conflicting provisioning settings` (Pod targets) | Pods have Automatic/Development signing, override conflicts | Apply Podfile `post_install` hook (Step 3) |
| `Cannot determine the Apple ID from Bundle ID` | App not created in App Store Connect | Create app first (Step 5, item 4) |
| `AuthKey file not found` | .p8 key not in expected location | Copy to `~/.appstoreconnect/private_keys/` |
| `Apple Developer Program not active` | Membership not paid | Complete $99/year enrollment at developer.apple.com |
