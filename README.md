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

### Pre-commit Checks

Install the shared git hook once:

```bash
pre-commit install
```

Run the full local pre-commit suite manually:

```bash
pre-commit run --all-files
```

Or run just the repo-owned fast checks directly:

```bash
scripts/pre_commit_checks.sh all
```

The pre-commit suite currently runs:

- `ruff` and `ruff-format`
- backend fast `pytest` coverage under `backend/tests/api`, `backend/tests/services`, `backend/tests/schemas`, and `backend/tests/observability`
- `flutter test` for the lightweight widget suite
- `flutter analyze`

### Flutter

```bash
cd flutter
cp .env.example .env
flutter pub get
flutter run -d ios
```

Flutter test documentation lives in [flutter/test/README.md](./flutter/test/README.md).
That file is the source of truth for:

- unit/widget tests
- deterministic mocked integration tests
- real auth/backend smoke tests
- required simulator/device setup
- pre-commit coverage vs manual-only coverage

Run the deterministic iOS UI flow tests locally:

```bash
cd flutter
flutter test integration_test/ui_flow_test.dart
```

**Rule:** You do **not** need to run the app first (`flutter run`). `flutter test integration_test` builds the app, installs and launches it on a device/simulator, and drives it from the test. Have a simulator booted (or a device connected); if multiple devices exist, pass `-d <device_id>` (e.g. `-d "iPhone 16 Pro"` or the ID from `flutter devices`).

Run the full integration suite, including the real sign-in smoke test, from a
local gitignored define file (same rule: no need to run the app first):

```bash
cd flutter
cp e2e.local.example.json e2e.local.json
flutter test integration_test --dart-define-from-file=e2e.local.json
```

`e2e.local.json` is gitignored and should contain:

```json
{
  "E2E_TEST_EMAIL": "your-test-email@example.com",
  "E2E_TEST_PASSWORD": "your-test-password"
}
```

Generate a local HTML quality report for the Flutter suite:

```bash
python3 scripts/flutter_test_report.py
```

This writes `index.html` plus raw logs into `flutter/test/output_results/`. The
generated report artifacts are gitignored.

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
