---
status: investigating
trigger: "Investigate failing deterministic integration test `saved timer appears on dashboard after save and can be drag-deleted` in the ai-wod-timer Flutter repo."
created: 2026-03-15T19:16:41Z
updated: 2026-03-15T19:19:05Z
---

## Current Focus

hypothesis: the new test is assuming an extra close step that the app no longer requires because save-from-X uses a save-then-exit flow
test: inspect the save modal return path and confirm whether successful save invoked from the timer X calls `_goBackToInput` immediately
expecting: if true, the timer cancel button should disappear after save and the dashboard should already be visible, making the second `timerCancelButton` tap invalid
next_action: read the save modal and save provider path, then run the focused test if feasible

## Symptoms

expected: after saving a created timer, closing the timer screen should return to dashboard, the saved timer card should appear with the chosen name, and it should be draggable to the delete zone.
actual: the test `saved timer appears on dashboard after save and can be drag-deleted` fails during the flow after save/close.
errors: latest user-facing output only shows the test name failed; earlier nearby failures in similar flows involved the top-left timer X being obscured by a lingering bottom sheet and/or dashboard text truncation.
reproduction: run `flutter test integration_test/ui_flow_test.dart --plain-name 'saved timer appears on dashboard after save and can be drag-deleted' -d <ios simulator>` from `flutter/`.
started: this started after adding the new dashboard save/delete flow test.

## Eliminated

## Evidence

- timestamp: 2026-03-15T19:19:05Z
  checked: flutter/integration_test/ui_flow_test.dart
  found: the failing test taps `timerCancelButton`, submits the save modal, waits for the modal to dismiss, then taps `timerCancelButton` a second time before asserting the dashboard is visible
  implication: the test assumes the save flow leaves the timer screen open after a successful save

- timestamp: 2026-03-15T19:19:05Z
  checked: flutter/lib/screens/timer/timer_screen.dart
  found: `_openEndSessionSavePrompt` sets `_saveThenExit = true` and `_showSaveWorkoutModal` calls `_goBackToInput(workout)` when `saved && shouldExitAfterSave`
  implication: a successful save initiated from the timer close button should already return to the dashboard without requiring a second close tap

- timestamp: 2026-03-15T19:19:05Z
  checked: flutter/lib/screens/timer/timer_screen.dart and flutter/lib/screens/app_shell.dart
  found: `_goBackToInput` clears the current workout and input state, and the timer screen switches back to the dashboard input view when `workout.currentWorkout == null`
  implication: after save-on-close succeeds, `timerCancelButton` should no longer be present and the dashboard should already be the active content

## Resolution

root_cause:
fix:
verification:
files_changed: []
