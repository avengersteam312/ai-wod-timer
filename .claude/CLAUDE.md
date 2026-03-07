# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Git Workflow
- **ALWAYS create a feature branch before making changes** - never commit directly to `master`
- Branch naming: `fix/`, `feat/`, `chore/` prefixes
- Create PR for all changes to merge into master

## Architecture Overview

This is a multi-platform AI-powered workout timer with three separate client implementations sharing one backend:

```
ai-wod-timer/
├── backend/          # FastAPI Python backend (primary API)
├── api/              # Vercel serverless entry point (wraps backend/)
├── frontend/         # Vue 3 + TypeScript + Capacitor web/mobile app
├── flutter/          # Flutter cross-platform app (alternative client)
├── supabase/         # DB migrations and config
└── promptfoo/        # Prompt evaluation test configs per workout type
```

### Backend (`backend/`)
FastAPI app using **OpenAI Agents SDK** (not Anthropic) for workout parsing. Two-stage AI pipeline:
1. **Classifier agent** (`gpt-4.1-mini`, temp=0) — fast, cheap workout type detection
2. **Parser agent** (`gpt-4o-mini`) — type-specific parsing using prompts from `app/prompts/`

Key files:
- `app/services/agent_workflow.py` — main AI pipeline (classifier → parser)
- `app/services/workout_parser.py` — non-agent fallback parser
- `app/prompts/` — one file per workout type (amrap, emom, tabata, for_time, intervals, custom, stopwatch)
- `app/api/v1/endpoints/timer.py` — `/api/v1/timer/parse` endpoint; supports `?use_agent=true/false` override
- `app/config.py` — `USE_AGENT_WORKFLOW` and `USE_CUSTOM_PROMPT_ONLY` feature flags

Auth uses Supabase JWT verification (`app/services/supabase_auth.py`).

### Frontend (`frontend/`)
Vue 3 + TypeScript app, deployable as web (Vercel) or native mobile (Capacitor).

State management with Pinia stores:
- `timerStore.ts` — timer FSM (IDLE → PREPARING → RUNNING → PAUSED → COMPLETED)
- `workoutStore.ts` — parsed workout data
- `supabaseAuthStore.ts` — auth state

Key composables: `useTimer.ts`, `useAudio.ts`, `useHaptics.ts`, `useOfflineStatus.ts`

Offline-first: uses Dexie (IndexedDB) for local storage, with `syncService.ts` to sync when online.

Native builds: `npm run build:mobile` → `cap sync` → open in Xcode/Android Studio.

### Flutter (`flutter/`)
Alternative Flutter client with Provider state management. Uses `supabase_flutter`, Hive for offline storage, and `audioplayers` for audio cues.

## Development Commands

### Docker (recommended for full stack)
```bash
./scripts/dev.sh              # Start all services with hot reload
./scripts/dev.sh backend      # Backend only (http://localhost:8000)
./scripts/dev.sh frontend     # Frontend only (http://localhost:5173)
./scripts/dev.sh down         # Stop all
docker compose logs -f        # View logs
```

### Backend (manual)
```bash
cd backend
source venv/bin/activate
uvicorn app.main:app --reload  # http://localhost:8000
# API docs: http://localhost:8000/api/v1/docs

pytest                         # Run tests
```

### Frontend (manual)
```bash
cd frontend
npm install
npm run dev                    # http://localhost:5173
npm run build                  # Web production build
npm run build:mobile           # Build + cap sync for native
npm run cap:ios                # Open in Xcode
npm run cap:android            # Open in Android Studio
```

### Flutter
```bash
cd flutter
flutter pub get
flutter run
flutter test
```

### Prompt Evaluation
```bash
# Uses promptfoo YAML configs in promptfoo/ directory
# One config per workout type: amrap.yaml, emom.yaml, tabata.yaml, etc.
python scripts/run_tests.py
```

## Environment Variables

**Backend** (`backend/.env`):
```env
OPENAI_API_KEY=             # Required — OpenAI key for AI agents
AI_MODEL=gpt-4o-mini
AI_CLASSIFIER_MODEL=gpt-4.1-mini
USE_AGENT_WORKFLOW=False    # True = two-stage agent pipeline; False = single-pass parser
DATABASE_URL=postgresql://...
SUPABASE_JWT_SECRET=        # From Supabase Dashboard > Settings > API
BACKEND_CORS_ORIGINS=["http://localhost:5173"]
```

**Frontend** (`frontend/.env`):
```env
VITE_API_URL=http://localhost:8000
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
```

## Workout Types
The system supports: `amrap`, `emom`, `for_time`, `tabata`, `intervals`, `stopwatch`, `custom`, `work_rest`

Each type has a dedicated prompt file in `backend/app/prompts/` and a Pinia test config in `promptfoo/`.

## Deployment
- Backend + frontend deployable via `docker-compose.yml`
- Frontend also deployable to Vercel (`vercel.json` at root and `frontend/vercel.json`)
- `api/index.py` is the Vercel serverless entry point that imports the FastAPI `app` from `backend/`

## Skills

Project-specific skills in `.claude/skills/`:

| Skill | Trigger | Purpose |
|-------|---------|---------|
| `wod-prompt` | editing `backend/app/prompts/`, improve parsing accuracy | Author/edit type-specific AI prompts with correct JSON schema |
| `wod-type` | add workout type, new timer type | 5-step checklist for adding a new workout type |
| `promptfoo-eval` | write promptfoo test, `promptfoo/*.yaml` | Write evaluation YAML configs with correct assertions |
| `wod-debug` | parsing wrong, wrong type detected, debug timer | Triage two-stage AI pipeline failures |
| `athlete-lens` | UX review, does this timer look right, user story | CrossFit athlete perspective on features and parsed timer output |
| `sentinel` | logging, metrics, tracing, alerting, monitoring, Sentry, Grafana, health check, auth failures, brute-force, observability | Staff observability engineer — builds and deploys the full prod observability stack from scratch |
| `ios-setup` | first ios deploy, setup ios deployment, ios app store setup, configure ios signing, first time app store | First-time Flutter iOS App Store setup: bundle ID, team ID, Podfile signing, ExportOptions, build → archive → export → upload |
| `ios-deploy` | deploy ios, release ios, upload to app store, new ios build, ios release, bump version ios, ship ios | Subsequent Flutter iOS deployments: bump version, build, archive, export IPA, upload to App Store Connect |
