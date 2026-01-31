# Supabase Setup Guide

This guide covers setting up Supabase as the backend for AI WOD Timer.

## 1. Create Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign in
2. Click **New Project**
3. Enter project details:
   - **Name**: ai-wod-timer (or your preference)
   - **Database Password**: Generate a strong password (save it)
   - **Region**: Choose closest to your users
4. Click **Create new project** and wait for setup (~2 minutes)

## 2. Get API Credentials

1. Go to **Project Settings → API**
2. Copy these values:
   - **Project URL**: `https://[project-id].supabase.co`
   - **Publishable API Key**: `sb_publishable_...`

3. Add to `frontend/.env`:
```env
VITE_SUPABASE_URL=https://[project-id].supabase.co
VITE_SUPABASE_ANON_KEY=sb_publishable_...
```

> Note: `.env` is gitignored. See `.env.example` for the template.

## 3. Run Database Migrations

Migration files are in `supabase/migrations/`. Apply them using one of these methods:

### Option A: Supabase CLI (Recommended)

```bash
# Login to Supabase (choose one method)
npx supabase login                      # Opens browser
npx supabase login --token <token>      # Use access token (Check shared API key in Apple Passwords or get from supabase.com/dashboard/account/tokens)

# Link to project (no global install needed - uses npx)
npx supabase link --project-ref gcqzvyopslwixvgaynwk

# Push migrations
npx supabase db push
```

Other useful commands:
```bash
npx supabase migration list          # Check migration status
npx supabase migration new my_change # Create new migration
npx supabase db pull                 # Pull remote schema changes
```

### Option B: SQL Editor (Manual)

1. Go to **Supabase Dashboard → SQL Editor**
2. Run each migration file in order:
   - `20260128000001_create_profiles_table.sql`
   - `20260128000002_create_workouts_table.sql`
   - `20260128000003_create_workout_sessions_table.sql`
   - `20260128000004_create_user_preferences_table.sql`

## 4. Configure Authentication

### Email/Password (Enabled by Default)

No additional setup needed. Users can sign up with email/password immediately.

### Google OAuth (Optional)

#### Step 1: Create Google OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing
3. Navigate to **APIs & Services → Credentials**
4. Click **Create Credentials → OAuth client ID**
5. Select **Web application**
6. Name it (e.g., `AI WOD Timer - Supabase`)
7. Add **Authorized redirect URI**:
   ```
   https://[project-id].supabase.co/auth/v1/callback
   ```
8. Click **Create** and copy:
   - **Client ID**
   - **Client Secret**

#### Step 2: Configure OAuth Consent Screen

1. Go to **APIs & Services → OAuth consent screen**
2. Select **External** user type
3. Fill required fields:
   - **App name**: AI WOD Timer
   - **User support email**: your email
   - **Developer contact**: your email
4. Add scopes: `email`, `profile`, `openid`
5. Save and continue

#### Step 3: Enable in Supabase

1. Go to **Supabase Dashboard → Authentication → Providers**
2. Find **Google** and toggle it **ON**
3. Enter:
   - **Client ID**: from Google Cloud Console
   - **Client Secret**: from Google Cloud Console
4. Save

## 5. Verify Setup

### Test Database Connection

```bash
cd frontend && npm run dev
```

Open browser console - no Supabase connection errors should appear.

### Test Authentication

1. Navigate to `/signup`
2. Create account with email/password
3. Check **Supabase Dashboard → Authentication → Users** - user should appear

### Test Google OAuth (if configured)

1. Click "Sign in with Google"
2. Complete Google sign-in flow
3. Verify redirect back to app and user created in Supabase

## Database Schema

### Tables

| Table | Description |
|-------|-------------|
| `profiles` | User display names, linked to auth.users |
| `workouts` | Saved workout configurations |
| `workout_sessions` | Completed workout history |
| `user_preferences` | User settings (audio, theme, etc.) |

### Row Level Security (RLS)

All tables have RLS enabled. Users can only access their own data:
- `auth.uid() = user_id` policy on all tables
- Profiles auto-created via trigger on user signup

## Troubleshooting

### "Provider not enabled" error
Google OAuth not configured. See section 4 above or use email/password auth.

### "Missing Supabase URL/Key" error
Check `frontend/.env` has correct values from Supabase dashboard.

### Tables not found
Run database migrations (section 3).

### CORS errors
Supabase handles CORS automatically. Check Project URL is correct in `.env`.
