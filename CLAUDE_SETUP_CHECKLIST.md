# Setup Checklist

Use this checklist to ensure everything is configured correctly before running the application.

## Prerequisites

- [ ] Docker installed and running
  - Check: `docker --version`
  - Check: `docker-compose --version`

OR (for manual setup):

- [ ] Python 3.11+ installed
  - Check: `python --version`
- [ ] Node.js 18+ installed
  - Check: `node --version`
- [ ] PostgreSQL 15+ installed (if running locally)
- [ ] Redis installed (if running locally)

## Configuration

### 1. Environment Variables

- [ ] Backend `.env` file exists
  - [ ] Copy from example: `cp backend/.env.example backend/.env`
  - [ ] Add Anthropic API key to `ANTHROPIC_API_KEY`
    - Get key from: https://console.anthropic.com/
    - Should start with `sk-ant-`

- [ ] Verify `.env` contains:
  ```bash
  # Check file exists
  ls backend/.env

  # Verify API key is set (should not be empty)
  grep ANTHROPIC_API_KEY backend/.env
  ```

### 2. Docker Setup (Recommended)

- [ ] Docker daemon is running
- [ ] No conflicts on ports:
  - [ ] Port 5173 available (frontend)
  - [ ] Port 8000 available (backend)
  - [ ] Port 5432 available (PostgreSQL)
  - [ ] Port 6379 available (Redis)

Check ports:
```bash
# macOS/Linux
lsof -i :5173
lsof -i :8000
lsof -i :5432
lsof -i :6379

# Windows
netstat -ano | findstr :5173
netstat -ano | findstr :8000
```

### 3. Manual Setup (Alternative)

If not using Docker:

#### Backend
- [ ] Virtual environment created
  ```bash
  cd backend
  python -m venv venv
  ```
- [ ] Virtual environment activated
  ```bash
  source venv/bin/activate  # macOS/Linux
  venv\Scripts\activate     # Windows
  ```
- [ ] Dependencies installed
  ```bash
  pip install -r requirements.txt
  ```
- [ ] PostgreSQL database created
  ```sql
  CREATE DATABASE ai_workout;
  ```
- [ ] Database URL configured in `.env`
- [ ] Redis server running

#### Frontend
- [ ] Dependencies installed
  ```bash
  cd frontend
  npm install
  ```
- [ ] No errors during install

## First Run

### Using Docker

1. [ ] Start all services:
   ```bash
   docker-compose up
   ```

2. [ ] Wait for services to start (look for these messages):
   - Backend: `Application startup complete`
   - Frontend: `Local: http://localhost:5173/`
   - PostgreSQL: `database system is ready to accept connections`
   - Redis: `Ready to accept connections`

3. [ ] Access the application:
   - [ ] Frontend loads: http://localhost:5173
   - [ ] Backend health check: http://localhost:8000/health
   - [ ] API docs load: http://localhost:8000/api/v1/docs

### Manual Setup

1. [ ] Start PostgreSQL
2. [ ] Start Redis
3. [ ] Start backend:
   ```bash
   cd backend
   source venv/bin/activate
   uvicorn app.main:app --reload
   ```
4. [ ] Start frontend (in new terminal):
   ```bash
   cd frontend
   npm run dev
   ```

## Testing

### Quick Smoke Test

1. [ ] Frontend loads without errors
2. [ ] Paste example workout:
   ```
   AMRAP 20min:
   10 Wall Balls
   10 Box Jumps
   10 Burpees
   ```
3. [ ] Click "Generate Timer"
4. [ ] Timer appears with correct time (20:00)
5. [ ] Start button works
6. [ ] Pause button works
7. [ ] Reset button works
8. [ ] Audio toggle works

### API Test

- [ ] Visit API docs: http://localhost:8000/api/v1/docs
- [ ] Try the `/timer/parse` endpoint with example workout
- [ ] Receive valid JSON response

### Detailed Test

- [ ] Test different workout types:
  - [ ] AMRAP
  - [ ] EMOM
  - [ ] For Time
  - [ ] Tabata
  - [ ] Rounds

- [ ] Audio cues work:
  - [ ] Start countdown (3-2-1-GO)
  - [ ] Time warnings
  - [ ] Completion beep

- [ ] Visual elements:
  - [ ] Timer updates every second
  - [ ] Progress bar advances
  - [ ] Movement list displays correctly
  - [ ] Colors change near completion

## Troubleshooting

### Backend Issues

**API key error:**
- [ ] Verify `.env` file has correct key
- [ ] Restart backend service
- [ ] Check logs: `docker-compose logs backend`

**Database connection error:**
- [ ] Verify PostgreSQL is running
- [ ] Check database URL in `.env`
- [ ] Ensure database exists

**Module import errors:**
- [ ] Reinstall dependencies: `pip install -r requirements.txt`
- [ ] Check Python version: `python --version` (need 3.11+)

### Frontend Issues

**Blank page:**
- [ ] Check browser console for errors
- [ ] Verify backend is running
- [ ] Check API proxy in `vite.config.ts`

**API errors:**
- [ ] Verify backend URL is correct
- [ ] Check CORS settings in backend
- [ ] Test backend directly: http://localhost:8000/health

**Build errors:**
- [ ] Delete `node_modules`: `rm -rf node_modules`
- [ ] Delete `package-lock.json`
- [ ] Reinstall: `npm install`
- [ ] Check Node version: `node --version` (need 18+)

### Docker Issues

**Port conflicts:**
- [ ] Stop conflicting services
- [ ] Or modify ports in `docker-compose.yml`

**Build errors:**
- [ ] Rebuild: `docker-compose up --build`
- [ ] Clear cache: `docker-compose build --no-cache`

**Container won't start:**
- [ ] Check logs: `docker-compose logs [service-name]`
- [ ] Verify `.env` file exists

## Final Verification

### Complete Workflow Test

1. [ ] Open http://localhost:5173
2. [ ] See "AI Workout Timer" heading
3. [ ] Click "Fran" example button
4. [ ] Workout text appears in textarea
5. [ ] Click "Generate Timer"
6. [ ] Loading indicator appears
7. [ ] Timer view loads with parsed workout
8. [ ] See "For Time" workout type
9. [ ] See movements listed (Thrusters, Pull-ups)
10. [ ] Click Start
11. [ ] Timer counts up
12. [ ] Click Pause
13. [ ] Timer stops
14. [ ] Click Reset
15. [ ] Timer returns to 0:00
16. [ ] Click "New Workout"
17. [ ] Back to input screen

### Performance Check

- [ ] Timer updates smoothly (no lag)
- [ ] UI is responsive
- [ ] No errors in browser console
- [ ] No errors in backend logs

## Ready to Go!

If all items are checked, you're ready to start using the AI Workout Timer!

## Next Steps

1. Read [EXAMPLE_WORKOUTS.md](EXAMPLE_WORKOUTS.md) for more workouts to try
2. Explore the API at http://localhost:8000/api/v1/docs
3. Check [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) to understand the codebase
4. Start customizing and adding features!

## Common Commands Reference

```bash
# Docker
docker-compose up                  # Start all services
docker-compose up -d               # Start in background
docker-compose down                # Stop all services
docker-compose logs backend        # View backend logs
docker-compose logs frontend       # View frontend logs
docker-compose restart backend     # Restart backend only
docker-compose up --build          # Rebuild and start

# Backend (manual)
cd backend
source venv/bin/activate
uvicorn app.main:app --reload      # Start with auto-reload
pytest                             # Run tests

# Frontend (manual)
cd frontend
npm install                        # Install dependencies
npm run dev                        # Start dev server
npm run build                      # Build for production
npm run preview                    # Preview production build
```

## Getting Help

If something isn't working:

1. Check this checklist again
2. Review error messages carefully
3. Check the logs:
   - Docker: `docker-compose logs`
   - Browser: Developer Console (F12)
4. Verify all environment variables are set
5. Try rebuilding: `docker-compose up --build`

Happy training! 💪
