# AI WOD Timer

Flutter iOS app with a FastAPI backend for AI workout parsing.

## Active Stack

- `flutter/`: active mobile client
- `backend/`: FastAPI API used by Flutter
- `supabase/`: schema and migrations for auth, workouts, sessions, preferences

Legacy Vue, Capacitor, and Vercel code has been removed from this repository.

## Local Development

### Backend

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload
```

Required backend env vars in `backend/.env`:

```env
OPENAI_API_KEY=your-openai-api-key
SUPABASE_JWT_SECRET=your-supabase-jwt-secret
```

Backend runs on `http://localhost:8000`.

### Flutter

```bash
cd flutter
cp .env.example .env
flutter pub get
flutter run -d ios
```

Required Flutter env vars:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-publishable-key
API_BASE_URL=http://localhost:8000
AUTH_ENABLED=true
DEEP_LINK_SCHEME=com.aiwodtimer.app
```

`AUTH_ENABLED` should remain enabled for normal app use. The backend parse endpoints require a valid Supabase access token.

## Backend API

- `POST /api/v1/timer/parse` (authenticated)
- `POST /api/v1/timer/parse-image` (authenticated)
- `GET /health`

## Supabase

Database migrations live in `supabase/migrations/`.

See `docs/supabase-setup.md` for setup details.
