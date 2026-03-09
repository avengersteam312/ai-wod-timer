# Supabase Setup Guide

This repository now uses Flutter as the only client. Supabase is used directly by the Flutter app for authentication and data storage.

## 1. Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) and create a project.
2. Copy:
   - Project URL
   - Publishable API key

## 2. Configure Flutter

Create `flutter/.env` from the example:

```bash
cd flutter
cp .env.example .env
```

Set:

```env
SUPABASE_URL=https://[project-id].supabase.co
SUPABASE_ANON_KEY=sb_publishable_...
API_BASE_URL=http://localhost:8000
AUTH_ENABLED=true
DEEP_LINK_SCHEME=com.aiwodtimer.app
```

The backend parse endpoints require a valid Supabase access token, so Flutter auth should remain enabled.

## 3. Configure the Backend

Create `backend/.env` from the example:

```bash
cd backend
cp .env.example .env
```

Set at minimum:

```env
OPENAI_API_KEY=your-openai-api-key
SUPABASE_JWT_SECRET=your-supabase-jwt-secret
```

`SUPABASE_JWT_SECRET` must come from `Supabase Dashboard -> Settings -> API -> JWT Secret`.

## 4. Apply Database Migrations

Migration files are in `supabase/migrations/`.

Recommended flow:

```bash
npx supabase login
npx supabase link --project-ref [project-id]
npx supabase db push
```

## 5. Configure Auth

Email/password works out of the box.

For Google OAuth:

1. Create Google OAuth credentials.
2. In Supabase, enable Google under `Authentication -> Providers`.
3. Add the Supabase callback URL:

```text
https://[project-id].supabase.co/auth/v1/callback
```

4. For iOS deep links, make sure the Flutter app's configured scheme matches `DEEP_LINK_SCHEME`.

## 6. Verify

Run the backend:

```bash
cd backend
uvicorn app.main:app --reload
```

Run Flutter:

```bash
cd flutter
flutter run -d ios
```

Confirm:

- Sign in / sign up works
- Supabase tables exist
- The app can parse workouts through the backend API after signing in
