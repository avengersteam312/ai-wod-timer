# Flutter vs Vue Parity Audit

## Summary

| Feature | Vue | Flutter | Status |
|---------|-----|---------|--------|
| Login/Auth | Yes | Yes | **Implemented** |
| Forgot Password | Yes | Yes | **Implemented** |
| My Workouts | Yes | Yes | **Implemented** |
| AI Timer | Yes | Partial | **Missing: Save, Voice toggle** |
| Manual Timer | Yes | Partial | **Missing: Countdown, Notes** |
| History | Yes | Yes | **Implemented** |
| Voice Toggle | Yes | No | **Missing UI** |
| Save Workouts | Yes | No | **Missing** |
| Offline Indicator | Yes | No | **Missing** |
| Notes Feature | Yes | No | **Missing** |
| Navigation | Yes | Yes | **Implemented** (4 tabs) |

---

## Screen-by-Screen Comparison

### 1. Login / Authentication Screens

**Vue Implementation (LoginView.vue + ForgotPasswordView.vue):**
- Sign In form with email/password
- Sign Up form with password confirmation
- Password visibility toggle (Eye/EyeOff icons)
- Google sign-in button with logo
- "Forgot Password" link → navigates to dedicated ForgotPasswordView
- ForgotPasswordView has email input + send reset link button
- Success messages for email confirmation
- Field-specific error messages
- General error display
- "Back to Login" / "Sign in" toggle

**Flutter Implementation (login_screen.dart + forgot_password_screen.dart):**
- Sign In/Sign Up toggle mode (both on same screen)
- Email field with validation
- Password field with visibility toggle
- Confirm password field (for signup only)
- Google sign-in button
- "Forgot Password?" text link navigates to separate ForgotPasswordScreen
- Error display via SnackBar (not inline)
- Success message via SnackBar after signup
- Password reset form with email input
- Success view after reset email sent

**Status:** ✅ IMPLEMENTED
**Minor Differences:**
- Flutter uses SnackBars for errors/success; Vue shows inline
- Flutter doesn't show the "password requirements" hint text
- Vue shows email confirmation success message; Flutter has basic SnackBar

---

### 2. My Workouts Screen

**Vue Implementation (MyWorkoutsView.vue):**
- Header with back button, title "My Workouts", offline indicator, profile menu
- Loading state with spinner
- Error state with "Try Again" button
- Empty state with icon, message, "Create a Workout" button
- Workout list with cards showing:
  - Workout name
  - Created date
  - Type badge (AMRAP, EMOM, etc)
  - Star icon to toggle favorite (with loading state)
  - Delete button (Trash icon)
- Delete confirmation modal (BottomSheet) with warning text
- Click on card to load workout into timer
- Refresh on list change

**Flutter Implementation (my_workouts_screen.dart):**
- AppBar with title and refresh button
- Loading state with CircularProgressIndicator
- Error state with error message and retry button
- Empty state with icon and "No Workouts Yet" message
- Workout list using ListView.builder with WorkoutCard widgets
- RefreshIndicator for pull-to-refresh
- Each card shows workout name, date, and type
- Favorite toggle and delete buttons
- Delete confirmation via AlertDialog
- Click to load and navigate to timer

**Status:** ✅ IMPLEMENTED
**Differences:**
- Flutter uses AlertDialog for delete confirmation; Vue uses BottomSheet
- Flutter shows "Go to Timer tab" text; Vue shows "Create a Workout"

---

### 3. Timer Screen (AI-Parsed Workouts)

**Vue Implementation (TimerView.vue):**
- Two modes: Workout Input OR Timer
- **Input Mode:**
  - WorkoutInput component with textarea
  - "Create Timer" button
  - Example workouts as buttons
  - Loading/parsing state
  - Error display
- **Timer Mode:**
  - Header: back button, title, offline indicator, save button, voice toggle, profile menu
  - Save workout modal with name input
  - Voice toggle (Volume2/VolumeX icons)
  - Save success toast (inline or offline save toast)
  - TimerBlock (display with ring)
  - RoundCounterBlock
  - ManualRoundCounterBlock
  - ControlsBlock (play/pause, reset, skip, end buttons)
  - WorkoutSummaryBlock
  - CurrentMovementBlock (shows current movement, next movement, or completion)
  - NextMovementBlock
  - "Start New Workout" button
  - WorkoutProgressBlock (movement list)

**Flutter Implementation (timer_screen.dart):**
- Two modes: Input View OR Timer View
- **Input Mode:**
  - TextField for workout input
  - Parse button with loading state
  - Example workout cards that populate input
  - Error display
- **Timer Mode:**
  - AppBar with title and profile button
  - AnimatedTimerRing showing progress
  - Round counter text
  - TimerControls widget (play/pause, reset, skip, complete)
  - CurrentMovementDisplay component
  - MovementList showing all movements
  - Completed state with celebration icon and "Start New Workout" button

**Status:** ⚠️ PARTIALLY IMPLEMENTED

**MISSING in Flutter:**
- [ ] Save workout feature (no ability to save parsed workouts)
- [ ] Voice/audio toggle button (audio feature exists but no UI toggle)
- [ ] Offline save toast notification
- [ ] Offline indicator in header
- [ ] Profile menu in header (Vue has this)

---

### 4. Manual Timer Screen

**Vue Implementation (ManualTimerView.vue + ManualTimer/ManualTimerSetup.vue):**
- Two steps: Select Type → Configure
- **Step 1: Timer Type Selector**
  - 8 timer types: Rest, Work&Rest, AMRAP, For Time, Tabata, Custom Interval, EMOM, Stopwatch
  - Each with icon, label, description
  - Click to select
- **Step 2: Configure**
  - TimerConfigHeader with back button and countdown selector
  - Type-specific config components:
    - RestTimerConfig: minutes/seconds input + quick start presets (1m, 2m, 5m, etc)
    - StopwatchConfig: no inputs needed
    - AmrapForTimeConfig: duration picker
    - TabataConfig: work/rest seconds, rounds
    - CustomIntervalConfig: work minutes/seconds, rest minutes/seconds, rounds
    - EmomConfig: rounds, interval minutes
    - WorkRestConfig: rounds
  - Add note button (opens BottomSheet for notes)
  - Start Timer button

**Flutter Implementation (manual_timer_screen.dart):**
- Single screen with:
  - TimerTypeSelector widget
  - Type description in info box
  - Dynamic config inputs based on type
  - Start Timer button

**Status:** ⚠️ PARTIALLY IMPLEMENTED

**MISSING in Flutter:**
- [ ] Countdown/preparation time selector (Vue has this via TimerConfigHeader)
- [ ] Notes feature (Vue allows adding notes to workouts)
- [ ] Custom Interval timer type may need verification

---

### 5. History Screen

**Vue Implementation (HistoryView.vue):**
- Header: back button, title "Workout History", offline indicator, profile menu
- Loading state with spinner
- Error state with "Try Again" button
- Empty state with icon and message
- Stats cards in grid (2 columns):
  - Total workouts (Trophy icon)
  - Total time (Timer icon)
- Session list grouped by date
- Each session card shows:
  - Workout name
  - Status badge (Completed/Abandoned/In Progress) with colors
  - Date and time
  - Duration with Clock icon
  - Workout type badge
- Click session to view details (modal)

**Flutter Implementation (history_screen.dart):**
- AppBar with title and refresh button
- Loading state with CircularProgressIndicator
- Error state with message and retry
- Empty state with icon and message
- Stats summary with 3 SessionStatCard widgets
- Sessions grouped by date (Today, Yesterday, etc)
- Each session card with details
- Tap session to show _SessionDetailsSheet

**Status:** ✅ IMPLEMENTED
**Differences:**
- Vue shows stats in grid; Flutter shows in row with 3 cards
- Flutter shows session details in draggable bottom sheet; Vue shows modal

---

### 6. Timer Controls

**Vue TimerControls.vue:**
- Reset button (48px, RotateCcw icon, disabled when idle)
- Play/Pause button (72px, Check/Pause/Play icons, disabled during countdown)
- Done button (for Work&Rest timer, Coffee icon)
- Skip to Next Interval button (or Dumbbell icon)
- End Timer button (Stop icon, red)
- Haptic feedback on actions
- Color coding: work (timer-work), rest (timer-rest), complete (timer-complete)

**Flutter TimerControls widget:**
- Play/Pause button (large, circular)
- Reset button
- Skip/Done/End buttons (conditional)

**Status:** ✅ IMPLEMENTED (core functionality present)

---

### 7. Navigation / Bottom Nav

**Vue BottomNav.vue:**
- Fixed bottom navigation with 3 items:
  - Manual (Timer icon)
  - AI Timer (Sparkles icon)
  - History (History icon)
- Active indicator (text + icon color changes to primary)
- Click clears workout state when switching between views

**Flutter AppShell:**
- BottomNavigationBar with 4 items:
  - Timer (timer icon)
  - Manual (tune icon)
  - Workouts (fitness_center icon)
  - History (history icon)
- IndexedStack to manage navigation

**Status:** ✅ IMPLEMENTED (Flutter has 4 tabs vs Vue's 3)

---

## Critical Missing Features

| Priority | Feature | Location | Notes |
|----------|---------|----------|-------|
| HIGH | Save Workout Feature | Timer Screen | Cannot save custom parsed workouts |
| HIGH | Voice/Audio Toggle UI | Timer Screen | No button to enable/disable voice cues |
| MEDIUM | Countdown/Preparation Timer | Manual Timer | Missing from configuration |
| MEDIUM | Workout Notes | Manual Timer | Cannot add notes to manual timers |
| LOW | Offline Indicator | All Screens | Not displayed in headers |
| LOW | Profile Menu | All Screens | Not shown consistently |

---

## Action Items

1. **Timer Screen:**
   - Add save workout button and modal
   - Add voice toggle button
   - Add offline indicator

2. **Manual Timer Screen:**
   - Add countdown/preparation time selector
   - Add notes feature

3. **All Screens:**
   - Add offline indicator component
   - Ensure consistent header/profile menu

---

*Generated: 2026-02-16*
