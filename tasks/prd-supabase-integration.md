# PRD: Supabase Integration for ai-wod-timer

## Overview
Evaluate and implement Supabase as the backend-as-a-service (BaaS) solution for ai-wod-timer, replacing or complementing Firebase for authentication, database, and storage needs.

## Problem Statement
Currently using Firebase for authentication. Need to evaluate Supabase as an alternative that offers:
- PostgreSQL database (relational, better for complex queries)
- Built-in Row Level Security (RLS)
- Real-time subscriptions
- Edge Functions
- Better pricing model for scaling
- Open-source and self-hostable

## Goals
1. Research Supabase capabilities and fit for ai-wod-timer
2. Prove feasibility with minimal PoC
3. Migrate authentication from Firebase to Supabase Auth
4. Design database schema for workouts, users, and timer sessions
5. Implement data persistence layer

## Non-Goals (for this PoC)
- Full production deployment
- Data migration from existing Firebase users
- Mobile app (Capacitor) integration
- Real-time features (future consideration)

---

## User Stories

### SPIKE-001: Research Supabase Architecture
**Priority:** P0
**Branch:** `spike/supabase-research`

**Description:**
Research Supabase capabilities, architecture patterns, and integration approach for Vue 3 + FastAPI stack.

**Acceptance Criteria:**
- [ ] Document Supabase Auth options (email/password, OAuth providers)
- [ ] Compare Supabase Auth vs Firebase Auth (features, migration path)
- [ ] Research Supabase client libraries for Vue 3
- [ ] Research Supabase integration with FastAPI backend
- [ ] Document Row Level Security (RLS) patterns
- [ ] Identify database schema requirements for workouts
- [ ] Create architecture decision record (ADR)
- [ ] Estimate effort for full migration

**Research Questions:**
1. Can we run Firebase Auth + Supabase DB together? (hybrid approach)
2. What's the migration path for existing Firebase users?
3. How does Supabase handle offline/sync scenarios?
4. What's the cost comparison at different user scales?

---

### SUP-001: Setup Supabase Project
**Priority:** P0
**Branch:** `feature/supabase-setup`
**Depends on:** SPIKE-001

**Description:**
Create Supabase project and configure basic environment.

**Acceptance Criteria:**
- [ ] Create Supabase project in dashboard
- [ ] Add Supabase environment variables to `.env.example`
- [ ] Install `@supabase/supabase-js` in frontend
- [ ] Create Supabase client initialization (`src/config/supabase.ts`)
- [ ] Verify connection from frontend
- [ ] Document setup steps in README

---

### SUP-002: Implement Supabase Authentication
**Priority:** P1
**Branch:** `feature/supabase-auth`
**Depends on:** SUP-001

**Description:**
Implement user authentication using Supabase Auth, replacing Firebase Auth.

**Acceptance Criteria:**
- [ ] Create Supabase auth store (`src/stores/supabaseAuthStore.ts`)
- [ ] Implement email/password sign-up
- [ ] Implement email/password sign-in
- [ ] Implement sign-out
- [ ] Implement auth state listener
- [ ] Implement password reset flow
- [ ] Update `LoginView.vue` to use Supabase auth
- [ ] Update `SignUpView.vue` to use Supabase auth
- [ ] Add Google OAuth provider (optional)
- [ ] Remove Firebase auth dependencies (or make switchable)

---

### SUP-003: Design Database Schema
**Priority:** P1
**Branch:** `feature/supabase-schema`
**Depends on:** SUP-001

**Description:**
Design and implement PostgreSQL schema for workouts and user data.

**Acceptance Criteria:**
- [ ] Create `users` table (extends Supabase auth.users)
- [ ] Create `workouts` table (parsed workout configurations)
- [ ] Create `workout_sessions` table (completed timer sessions)
- [ ] Implement Row Level Security policies
- [ ] Create database migrations
- [ ] Document schema in `docs/database-schema.md`

**Schema Draft:**
```sql
-- Users profile extension
create table public.profiles (
  id uuid references auth.users primary key,
  display_name text,
  created_at timestamptz default now()
);

-- Saved workouts
create table public.workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  name text not null,
  raw_input text,
  parsed_config jsonb not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Workout history
create table public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users not null,
  workout_id uuid references public.workouts,
  started_at timestamptz not null,
  completed_at timestamptz,
  duration_seconds int,
  status text default 'in_progress'
);
```

---

### SUP-004: Implement Workout CRUD Operations
**Priority:** P2
**Branch:** `feature/supabase-workout-crud`
**Depends on:** SUP-002, SUP-003

**Description:**
Implement create, read, update, delete operations for workouts using Supabase.

**Acceptance Criteria:**
- [ ] Create workout service (`src/services/workoutService.ts`)
- [ ] Implement save workout functionality
- [ ] Implement list user's workouts
- [ ] Implement load workout by ID
- [ ] Implement update workout
- [ ] Implement delete workout
- [ ] Add "Save Workout" button to timer view
- [ ] Create "My Workouts" page to list saved workouts

---

### SUP-005: Track Workout Sessions
**Priority:** P2
**Branch:** `feature/supabase-sessions`
**Depends on:** SUP-004

**Description:**
Track workout session history (when users complete timers).

**Acceptance Criteria:**
- [ ] Create session service (`src/services/sessionService.ts`)
- [ ] Auto-create session record when timer starts
- [ ] Update session when timer completes
- [ ] Create "Workout History" page
- [ ] Display basic stats (total workouts, total time)

---

### SUP-006: Backend API Integration (Optional)
**Priority:** P3
**Branch:** `feature/supabase-backend`
**Depends on:** SUP-001

**Description:**
Integrate Supabase with FastAPI backend for server-side operations.

**Acceptance Criteria:**
- [ ] Install `supabase-py` in backend
- [ ] Configure Supabase client in backend
- [ ] Update `/timer/parse` endpoint to optionally save workout
- [ ] Implement server-side token verification
- [ ] Document API changes

---

## Technical Notes

### Environment Variables
```
VITE_SUPABASE_URL=https://[project-ref].supabase.co
VITE_SUPABASE_ANON_KEY=[anon-key]
```

### File Structure
```
frontend/src/
├── config/
│   └── supabase.ts          # Supabase client init
├── stores/
│   └── supabaseAuthStore.ts # Auth state management
├── services/
│   ├── workoutService.ts    # Workout CRUD
│   └── sessionService.ts    # Session tracking
└── views/
    ├── MyWorkoutsView.vue   # Saved workouts list
    └── HistoryView.vue      # Workout history
```

### Migration Strategy
1. Start with Supabase for new features (workout storage)
2. Run Firebase + Supabase in parallel during transition
3. Migrate auth last (most disruptive)
4. Deprecate Firebase after full migration

---

## Success Metrics
- [ ] Authentication working with Supabase
- [ ] Users can save and retrieve workouts
- [ ] Workout history is persisted
- [ ] No regressions in existing functionality
- [ ] Clear documentation for team

## Timeline
- Spike: 1 story point
- Setup + Auth: 3 story points
- Schema + CRUD: 3 story points
- Sessions: 2 story points
- Backend (optional): 2 story points

**Total PoC: ~11 story points**
