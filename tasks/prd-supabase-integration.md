# PRD: Supabase Full Integration

## Introduction

Replace Firebase with Supabase as the complete backend solution for ai-wod-timer, including authentication, database, and real-time features. This enables persistent workout storage, session history tracking, user preferences, and real-time sync across devices. The implementation must be offline-first to support mobile usage in areas with poor connectivity (gyms, outdoors).

## Why Replace Firebase Auth with Supabase Auth

### Decision: Full Supabase Migration (not hybrid)

**Reasoning:**

1. **Unified Platform Simplicity**
   - Single SDK, single dashboard, single billing
   - No JWT token bridging complexity between Firebase and Supabase
   - Simpler debugging (one auth system, one database)
   - Reduced bundle size (no Firebase SDK)

2. **Native RLS Integration**
   - Supabase Auth works seamlessly with Row Level Security
   - `auth.uid()` in RLS policies without custom JWT verification
   - No custom token passing or header configuration needed

3. **Cost Efficiency**
   - Firebase Auth free tier: 10K authentications/month
   - Supabase Auth free tier: 50K monthly active users
   - Single vendor billing vs managing two services

4. **Feature Parity (Question 3: 3B + 3C)**

   Current Firebase implementation (`frontend/src/stores/authStore.ts`):
   - Email/password sign-in/sign-up ✓
   - Google OAuth ✓
   - Password reset ✓

   Supabase will match all existing Firebase auth methods:
   | Feature | Firebase (current) | Supabase (target) |
   |---------|-------------------|-------------------|
   | Email/password | ✓ | ✓ |
   | Google OAuth | ✓ | ✓ |
   | Password reset | ✓ | ✓ |
   | Email verification | ✓ | ✓ |
   | Session persistence | ✓ | ✓ |

   *No additional providers needed - 3B (Email + Google) covers all current Firebase functionality.*

5. **Future-Proofing**
   - Supabase is open-source and self-hostable
   - No vendor lock-in for auth
   - Easier to migrate if needed later

6. **Technical Debt Avoidance**
   - Hybrid approach requires: Firebase SDK + Supabase SDK + JWT bridge
   - Full migration: Just Supabase SDK
   - Less code to maintain, fewer failure points

**Trade-offs Accepted:**
- Existing Firebase users will need to re-register (acceptable for PoC/early stage)
- Team needs to learn Supabase Auth (minimal learning curve)

---

## Goals

- Replace Firebase Authentication with Supabase Auth (email/password + Google OAuth)
- Persist user workouts to Supabase PostgreSQL database
- Track completed workout sessions with duration and stats
- Store user preferences (audio settings, theme, defaults)
- Enable real-time sync across devices (phone ↔ tablet ↔ web)
- Support offline-first for mobile (Capacitor) - works without internet, syncs when connected
- Production-ready implementation with proper error handling

## User Stories

### US-001: Setup Supabase Project and Client
**Description:** As a developer, I need Supabase configured in the project so I can build features on top of it.

**Acceptance Criteria:**
- [ ] Create Supabase project in dashboard
- [ ] Add environment variables to `.env.example`: `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`
- [ ] Install `@supabase/supabase-js` in frontend
- [ ] Create `src/config/supabase.ts` with client initialization
- [ ] Verify connection works (simple query test)
- [ ] Document setup steps in `docs/supabase-setup.md`
- [ ] Typecheck passes

---

### US-002: Implement Supabase Auth - Sign Up
**Description:** As a new user, I want to create an account with email and password.

**Acceptance Criteria:**
- [ ] Create `src/stores/supabaseAuthStore.ts` (replace Firebase auth store)
- [ ] Implement `signUp(email, password)` method
- [ ] Handle email confirmation flow (if enabled)
- [ ] Store user in Pinia state on success
- [ ] Show appropriate error messages (email taken, weak password, etc.)
- [ ] Typecheck passes

---

### US-003: Implement Supabase Auth - Sign In
**Description:** As a returning user, I want to sign in with my email and password.

**Acceptance Criteria:**
- [ ] Implement `signIn(email, password)` method
- [ ] Handle "email not confirmed" error gracefully
- [ ] Redirect to home/timer page on success
- [ ] Show error for invalid credentials
- [ ] Typecheck passes

---

### US-004: Implement Supabase Auth - Sign Out
**Description:** As a user, I want to sign out of my account.

**Acceptance Criteria:**
- [ ] Implement `signOut()` method
- [ ] Clear local state and redirect to login
- [ ] Clear any cached data (IndexedDB optional clear)
- [ ] Typecheck passes

---

### US-005: Implement Supabase Auth - Session Persistence
**Description:** As a user, I want to stay logged in when I refresh or reopen the app.

**Acceptance Criteria:**
- [ ] Listen to `onAuthStateChange` events
- [ ] Restore session on app load
- [ ] Handle token refresh automatically
- [ ] Update Pinia store on auth state changes
- [ ] Typecheck passes

---

### US-006: Implement Supabase Auth - Password Reset
**Description:** As a user, I want to reset my password if I forget it.

**Acceptance Criteria:**
- [ ] Implement `resetPassword(email)` method
- [ ] Send password reset email via Supabase
- [ ] Handle reset link callback in app
- [ ] Implement `updatePassword(newPassword)` for the reset flow
- [ ] Typecheck passes

---

### US-007: Implement Supabase Auth - Google OAuth
**Description:** As a user, I want to sign in with my Google account.

**Acceptance Criteria:**
- [ ] Configure Google OAuth provider in Supabase dashboard
- [ ] Implement `signInWithGoogle()` method
- [ ] Handle OAuth redirect flow
- [ ] Create profile on first OAuth sign-in
- [ ] Typecheck passes
- [ ] Verify in browser using dev-browser skill

---

### US-008: Update Login/SignUp Views for Supabase
**Description:** As a developer, I need to update the auth UI to use Supabase instead of Firebase.

**Acceptance Criteria:**
- [ ] Update `LoginView.vue` to use supabaseAuthStore
- [ ] Update `SignUpView.vue` to use supabaseAuthStore
- [ ] Update `ForgotPasswordView.vue` (if exists) or create it
- [ ] Add Google sign-in button
- [ ] Remove all Firebase auth imports
- [ ] Typecheck passes
- [ ] Verify in browser using dev-browser skill

---

### US-009: Remove Firebase Dependencies
**Description:** As a developer, I want to remove Firebase to reduce bundle size and complexity.

**Acceptance Criteria:**
- [ ] Remove `firebase` package from package.json
- [ ] Delete `src/config/firebase.ts`
- [ ] Delete `src/stores/authStore.ts` (old Firebase store)
- [ ] Remove Firebase env variables from `.env.example`
- [ ] Update any remaining Firebase imports
- [ ] Verify app builds and runs without Firebase
- [ ] Typecheck passes

---

### US-010: Create Database Schema - Profiles
**Description:** As a developer, I need a profiles table to store user display names and metadata.

**Acceptance Criteria:**
- [ ] Create `profiles` table linked to auth.users
- [ ] Columns: `id` (UUID, FK to auth.users), `display_name`, `created_at`, `updated_at`
- [ ] Enable RLS - users can only read/write own profile
- [ ] Create trigger to auto-create profile on user signup
- [ ] Create SQL migration file in `supabase/migrations/`
- [ ] Typecheck passes

**Schema:**
```sql
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  display_name text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.profiles enable row level security;

create policy "Users can view own profile"
  on public.profiles for select using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);

-- Auto-create profile on signup
create function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, new.raw_user_meta_data->>'full_name');
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
```

---

### US-011: Create Database Schema - Workouts
**Description:** As a developer, I need a workouts table to store parsed workout configurations.

**Acceptance Criteria:**
- [ ] Create `workouts` table with user reference
- [ ] Columns: `id`, `user_id`, `name`, `raw_input`, `parsed_config` (JSONB), `is_favorite`, `created_at`, `updated_at`
- [ ] Enable RLS - users can only access own workouts
- [ ] Create SQL migration file
- [ ] Typecheck passes

**Schema:**
```sql
create table public.workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users on delete cascade not null,
  name text not null,
  raw_input text,
  parsed_config jsonb not null,
  is_favorite boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index workouts_user_id_idx on public.workouts(user_id);

alter table public.workouts enable row level security;

create policy "Users can CRUD own workouts"
  on public.workouts for all using (auth.uid() = user_id);
```

---

### US-012: Create Database Schema - Workout Sessions
**Description:** As a developer, I need a sessions table to track completed workout history.

**Acceptance Criteria:**
- [ ] Create `workout_sessions` table
- [ ] Columns: `id`, `user_id`, `workout_id` (nullable), `workout_snapshot` (JSONB), `started_at`, `completed_at`, `duration_seconds`, `status`
- [ ] Status enum: 'in_progress', 'completed', 'abandoned'
- [ ] Enable RLS - users can only access own sessions
- [ ] Create SQL migration file
- [ ] Typecheck passes

**Schema:**
```sql
create table public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users on delete cascade not null,
  workout_id uuid references public.workouts(id) on delete set null,
  workout_snapshot jsonb not null,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  duration_seconds int,
  status text default 'in_progress' check (status in ('in_progress', 'completed', 'abandoned'))
);

create index sessions_user_id_idx on public.workout_sessions(user_id);

alter table public.workout_sessions enable row level security;

create policy "Users can CRUD own sessions"
  on public.workout_sessions for all using (auth.uid() = user_id);
```

---

### US-013: Create Database Schema - User Preferences
**Description:** As a developer, I need a preferences table to store user settings.

**Acceptance Criteria:**
- [ ] Create `user_preferences` table
- [ ] Columns: `user_id` (PK), `audio_enabled`, `voice_type`, `theme`, `default_rest_seconds`, `countdown_seconds`
- [ ] Enable RLS - users can only access own preferences
- [ ] Create SQL migration file
- [ ] Typecheck passes

**Schema:**
```sql
create table public.user_preferences (
  user_id uuid references auth.users on delete cascade primary key,
  audio_enabled boolean default true,
  voice_type text default 'female',
  theme text default 'dark',
  default_rest_seconds int default 60,
  countdown_seconds int default 10,
  updated_at timestamptz default now()
);

alter table public.user_preferences enable row level security;

create policy "Users can CRUD own preferences"
  on public.user_preferences for all using (auth.uid() = user_id);
```

---

### US-014: Create Workout Service - Save Workout
**Description:** As a user, I want to save my parsed workout so I can reuse it later.

**Acceptance Criteria:**
- [ ] Create `src/services/workoutService.ts`
- [ ] Implement `saveWorkout(workout: ParsedWorkout, name: string): Promise<Workout>`
- [ ] Save includes raw input and parsed config
- [ ] Returns saved workout with ID
- [ ] Typecheck passes

---

### US-015: Create Workout Service - List Workouts
**Description:** As a user, I want to see all my saved workouts so I can pick one to run.

**Acceptance Criteria:**
- [ ] Implement `getWorkouts(): Promise<Workout[]>`
- [ ] Returns workouts sorted by `updated_at` desc
- [ ] Includes favorite status
- [ ] Typecheck passes

---

### US-016: Create Workout Service - Load Workout
**Description:** As a user, I want to load a saved workout to run it again.

**Acceptance Criteria:**
- [ ] Implement `getWorkout(id: string): Promise<Workout>`
- [ ] Returns full workout with parsed config
- [ ] Throws error if not found or not owned
- [ ] Typecheck passes

---

### US-017: Create Workout Service - Update Workout
**Description:** As a user, I want to update a saved workout's name or favorite status.

**Acceptance Criteria:**
- [ ] Implement `updateWorkout(id: string, updates: Partial<Workout>): Promise<Workout>`
- [ ] Can update: name, is_favorite
- [ ] Updates `updated_at` timestamp
- [ ] Typecheck passes

---

### US-018: Create Workout Service - Delete Workout
**Description:** As a user, I want to delete a workout I no longer need.

**Acceptance Criteria:**
- [ ] Implement `deleteWorkout(id: string): Promise<void>`
- [ ] Removes workout from database
- [ ] Associated sessions keep workout_snapshot (don't delete)
- [ ] Typecheck passes

---

### US-019: Create Session Service - Start Session
**Description:** As a user, I want my workout session tracked when I start the timer.

**Acceptance Criteria:**
- [ ] Create `src/services/sessionService.ts`
- [ ] Implement `startSession(workout: ParsedWorkout, workoutId?: string): Promise<Session>`
- [ ] Creates session with status 'in_progress'
- [ ] Stores workout_snapshot (copy of workout config)
- [ ] Returns session with ID
- [ ] Typecheck passes

---

### US-020: Create Session Service - Complete Session
**Description:** As a user, I want my completed workout recorded with duration.

**Acceptance Criteria:**
- [ ] Implement `completeSession(sessionId: string, durationSeconds: number): Promise<Session>`
- [ ] Updates status to 'completed'
- [ ] Sets completed_at and duration_seconds
- [ ] Typecheck passes

---

### US-021: Create Session Service - Abandon Session
**Description:** As a user, I want incomplete sessions marked as abandoned (not deleted).

**Acceptance Criteria:**
- [ ] Implement `abandonSession(sessionId: string): Promise<void>`
- [ ] Updates status to 'abandoned'
- [ ] Keeps record for history
- [ ] Typecheck passes

---

### US-022: Create Session Service - Get History
**Description:** As a user, I want to see my workout history.

**Acceptance Criteria:**
- [ ] Implement `getSessionHistory(limit?: number): Promise<Session[]>`
- [ ] Returns sessions sorted by started_at desc
- [ ] Includes workout_snapshot for display
- [ ] Default limit 50
- [ ] Typecheck passes

---

### US-023: Create Preferences Service
**Description:** As a user, I want my preferences saved and loaded automatically.

**Acceptance Criteria:**
- [ ] Create `src/services/preferencesService.ts`
- [ ] Implement `getPreferences(): Promise<Preferences>`
- [ ] Implement `updatePreferences(prefs: Partial<Preferences>): Promise<Preferences>`
- [ ] Auto-create default preferences if none exist
- [ ] Typecheck passes

---

### US-024: Add Save Workout Button to Timer View
**Description:** As a user, I want to save my workout after parsing it.

**Acceptance Criteria:**
- [ ] Add "Save Workout" button to timer header
- [ ] Shows modal to enter workout name
- [ ] Calls workoutService.saveWorkout
- [ ] Shows success toast
- [ ] Button disabled if already saved (shows saved indicator)
- [ ] Typecheck passes
- [ ] Verify in browser using dev-browser skill

---

### US-025: Create My Workouts Page
**Description:** As a user, I want a page to see and manage my saved workouts.

**Acceptance Criteria:**
- [ ] Create `src/views/MyWorkoutsView.vue`
- [ ] Lists saved workouts with name, created date
- [ ] Click workout to load and run
- [ ] Favorite toggle (star icon)
- [ ] Delete button with confirmation
- [ ] Empty state when no workouts
- [ ] Add route `/workouts`
- [ ] Typecheck passes
- [ ] Verify in browser using dev-browser skill

---

### US-026: Create Workout History Page
**Description:** As a user, I want to see my workout history and stats.

**Acceptance Criteria:**
- [ ] Create `src/views/HistoryView.vue`
- [ ] Lists completed sessions with date, workout name, duration
- [ ] Shows basic stats: total workouts, total time, streak
- [ ] Click session to see details
- [ ] Add route `/history`
- [ ] Typecheck passes
- [ ] Verify in browser using dev-browser skill

---

### US-027: Add Navigation to New Pages
**Description:** As a user, I want to navigate to My Workouts and History pages.

**Acceptance Criteria:**
- [ ] Add navigation links/buttons to main layout
- [ ] Show in header or sidebar
- [ ] Highlight active page
- [ ] Mobile-friendly navigation
- [ ] Typecheck passes
- [ ] Verify in browser using dev-browser skill

---

### US-028: Setup Offline Storage with Dexie
**Description:** As a developer, I need local IndexedDB storage for offline-first support.

**Acceptance Criteria:**
- [ ] Install `dexie` for IndexedDB wrapper
- [ ] Create `src/services/offlineDb.ts`
- [ ] Define local tables: workouts, sessions, preferences, syncQueue
- [ ] Create CRUD methods for local storage
- [ ] Typecheck passes

---

### US-029: Implement Offline Queue for Mutations
**Description:** As a user, I want changes made offline to sync when I'm back online.

**Acceptance Criteria:**
- [ ] Create sync queue table for pending mutations
- [ ] Queue structure: { id, table, operation, data, createdAt }
- [ ] Save mutations to queue when offline
- [ ] Typecheck passes

---

### US-030: Implement Sync Service
**Description:** As a user, I want my offline changes synced automatically when online.

**Acceptance Criteria:**
- [ ] Create `src/services/syncService.ts`
- [ ] Detect online/offline status
- [ ] Process sync queue when online
- [ ] Handle conflicts (server wins for now)
- [ ] Clear queue items after successful sync
- [ ] Typecheck passes

---

### US-031: Enable Real-time Subscriptions
**Description:** As a user, I want changes on other devices to appear in real-time.

**Acceptance Criteria:**
- [ ] Subscribe to workouts table changes
- [ ] Subscribe to preferences changes
- [ ] Update local state when remote changes detected
- [ ] Unsubscribe on logout/unmount
- [ ] Typecheck passes

---

### US-032: Handle Offline State in UI
**Description:** As a user, I want to know when I'm offline and that my data is safe.

**Acceptance Criteria:**
- [ ] Show offline indicator in header when disconnected
- [ ] Show "Syncing..." indicator when processing queue
- [ ] Show "Saved locally" confirmation for offline saves
- [ ] Disable features that require online (if any)
- [ ] Typecheck passes
- [ ] Verify in browser using dev-browser skill

---

### US-033: Integration Testing - Full Flow
**Description:** As a developer, I need tests to verify the full Supabase integration works.

**Acceptance Criteria:**
- [ ] Test: Sign up → verify email → sign in → works
- [ ] Test: Create workout → save → reload page → workout persists
- [ ] Test: Start session → complete → appears in history
- [ ] Test: Offline save → go online → syncs to server
- [ ] Test: Change on device A → appears on device B (real-time)
- [ ] Typecheck passes

---

## Functional Requirements

- FR-1: All database operations must use Row Level Security (users access only own data)
- FR-2: Supabase Auth must handle all authentication (no Firebase)
- FR-3: Workouts must store both raw input and parsed JSON config
- FR-4: Sessions must snapshot workout config (independent of workout deletion)
- FR-5: Offline mutations must queue and sync when online
- FR-6: Real-time subscriptions must update local state within 2 seconds
- FR-7: All services must handle errors gracefully with user-friendly messages
- FR-8: Local IndexedDB must be primary source, synced with Supabase

## Non-Goals

- Migrating existing Firebase users (fresh start for PoC)
- Social features (sharing workouts, leaderboards)
- Complex conflict resolution (using server-wins strategy)
- Analytics/reporting beyond basic stats
- Backup/export functionality

## Technical Considerations

- **Auth**: Supabase Auth with email/password + Google OAuth
- **Offline Strategy**: Dexie (IndexedDB) as primary store, Supabase as sync target
- **Real-time**: Supabase Realtime uses WebSockets, auto-reconnects
- **Capacitor**: IndexedDB works in WebView, test on actual devices
- **Type Safety**: Generate TypeScript types from Supabase schema using `supabase gen types`

## Design Considerations

- Offline indicator should be subtle but visible (gray dot in header)
- Sync indicator should be non-blocking (small spinner near indicator)
- My Workouts page should match existing dark theme
- History page should show visual timeline or list

## Success Metrics

- [ ] Users can sign up and sign in with Supabase Auth
- [ ] Users can save and load workouts across sessions
- [ ] Workout history persists and shows accurate stats
- [ ] App works fully offline (timer runs, saves locally)
- [ ] Offline changes sync within 30 seconds of reconnection
- [ ] Real-time sync works across devices (< 2 second delay)
- [ ] No data loss during offline/online transitions
- [ ] Firebase SDK completely removed from bundle

## Open Questions

1. Should we implement soft-delete for workouts (archive vs delete)?
2. What's the maximum number of workouts/sessions to store locally for offline?
3. Should preferences sync in real-time or only on app load?
4. Do we need a "Force Sync" button for users?
