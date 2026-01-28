# Ralph Agent Instructions

You are an autonomous coding agent working on the AI Workout Timer project.

## Project Context

This is a full-stack application:
- **Backend**: Python 3.11+ with FastAPI, PostgreSQL, OpenAI API
- **Frontend**: Vue 3 + TypeScript + Vite + TailwindCSS
- **Infrastructure**: Docker Compose for local development

## Your Task

1. Read the PRD at `scripts/ralph/prd.json`
2. Read the progress log at `scripts/ralph/progress.txt` (check Codebase Patterns section first)
3. Check you're on the correct branch from PRD `branchName`. If not, check it out or create from main.
4. Pick the **highest priority** user story where `passes: false`
5. Implement that single user story
6. Run quality checks (see Quality Checks section below)
7. Update AGENTS.md files if you discover reusable patterns (see below)
8. If checks pass, commit ALL changes with message: `feat: [Story ID] - [Story Title]`
9. Update the PRD to set `passes: true` for the completed story
10. Append your progress to `scripts/ralph/progress.txt`

## Quality Checks

Before committing, you MUST run these checks:

### Backend (Python)
```bash
cd backend
# Type checking (if mypy is configured)
# pytest for tests
pytest
# Ensure no syntax errors
python -m py_compile app/**/*.py
```

### Frontend (Vue/TypeScript)
```bash
cd frontend
# Type checking
npm run build  # This runs vue-tsc -b
# Or just type check without building:
npx vue-tsc --noEmit
```

### Both
- Ensure Docker Compose still works (if applicable)
- Check that environment variables are properly configured
- Verify API endpoints work if backend changes were made

## Progress Report Format

APPEND to `scripts/ralph/progress.txt` (never replace, always append):
```
## [Date/Time] - [Story ID]
- What was implemented
- Files changed
- **Learnings for future iterations:**
  - Patterns discovered (e.g., "this codebase uses X for Y")
  - Gotchas encountered (e.g., "don't forget to update Z when changing W")
  - Useful context (e.g., "the timer component is in components/timer/")
---
```

The learnings section is critical - it helps future iterations avoid repeating mistakes and understand the codebase better.

## Consolidate Patterns

If you discover a **reusable pattern** that future iterations should know, add it to the `## Codebase Patterns` section at the TOP of `scripts/ralph/progress.txt` (create it if it doesn't exist):

```
## Codebase Patterns
- Backend uses FastAPI with Pydantic schemas in app/schemas/
- Frontend uses Vue 3 Composition API with TypeScript
- Timer state is managed in frontend/src/stores/timerStore.ts
- API client is in frontend/src/services/api.ts
- Always run pytest for backend changes
- Always run vue-tsc for frontend type checking
```

Only add patterns that are **general and reusable**, not story-specific details.

## Update AGENTS.md Files

Before committing, check if any edited files have learnings worth preserving in nearby AGENTS.md files:

1. **Identify directories with edited files** - Look at which directories you modified
2. **Check for existing AGENTS.md** - Look for AGENTS.md in those directories or parent directories
3. **Add valuable learnings** - If you discovered something future developers/agents should know:
   - API patterns or conventions specific to that module
   - Gotchas or non-obvious requirements
   - Dependencies between files
   - Testing approaches for that area
   - Configuration or environment requirements

**Examples of good AGENTS.md additions:**
- "When modifying timer store, also update useTimer composable to keep them in sync"
- "Backend endpoints use Pydantic schemas from app/schemas/"
- "Frontend API calls go through api.ts service which handles auth tokens"
- "Timer components require timerStore to be initialized"

**Do NOT add:**
- Story-specific implementation details
- Temporary debugging notes
- Information already in progress.txt

Only update AGENTS.md if you have **genuinely reusable knowledge** that would help future work in that directory.

## Project-Specific Guidelines

### Backend
- Use FastAPI dependency injection for auth (see `app/api/v1/dependencies.py`)
- Firebase authentication is handled via `app/services/firebase_service.py`
- AI service uses OpenAI (see `app/services/ai_service.py`)
- Database models are in `app/models/` using SQLAlchemy
- API endpoints are in `app/api/v1/endpoints/`

### Frontend
- State management uses Pinia stores in `src/stores/`
- Components are organized by feature (timer, manual-timer, ui)
- Composables are in `src/composables/` for reusable logic
- Firebase config is in `src/config/firebase.ts`
- API service handles auth tokens automatically (see `src/services/api.ts`)

### Testing
- Backend: Use pytest (see `backend/requirements.txt`)
- Frontend: Type checking via vue-tsc
- LLM prompts: Use promptfoo tests in `promptfoo/` directory

## Browser Testing (If Available)

For any story that changes UI, verify it works in the browser if you have browser testing tools configured (e.g., via MCP or browser automation):

1. Start the frontend dev server: `cd frontend && npm run dev`
2. Navigate to the relevant page (usually http://localhost:5173)
3. Verify the UI changes work as expected
4. Test on different screen sizes if responsive changes were made
5. Take a screenshot if helpful for the progress log

If no browser tools are available, note in your progress report that manual browser verification is needed. Frontend stories can still be marked complete if type checking passes and the code changes are correct, but browser verification should be performed manually when possible.

## Stop Condition

After completing a user story, check if ALL stories have `passes: true`.

If ALL stories are complete and passing, reply with:
```
<promise>COMPLETE</promise>
```

If there are still stories with `passes: false`, end your response normally (another iteration will pick up the next story).

## Important

- Work on ONE story per iteration
- Commit frequently
- Keep CI green (if CI is set up)
- Read the Codebase Patterns section in progress.txt before starting
- Always run quality checks before committing
- Frontend changes should be verified in browser if tools are available, otherwise note manual verification needed
