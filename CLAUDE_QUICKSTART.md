# Quick Start Guide

Get the AI Workout Timer running in 5 minutes!

## Option 1: Docker (Recommended)

### Step 1: Add API Key
1. Open `backend/.env`
2. Add your Anthropic API key:
   ```
   ANTHROPIC_API_KEY=sk-ant-xxxxx
   ```

   Get your API key from: https://console.anthropic.com/

### Step 2: Start Everything
```bash
docker-compose up
```

### Step 3: Access the App
- Open http://localhost:5173 in your browser
- The API docs are at http://localhost:8000/api/v1/docs

That's it! Try pasting a workout and clicking "Generate Timer".

---

## Option 2: Manual Setup (Development)

### Backend

```bash
# Terminal 1 - Backend
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Add your API key to .env
echo "ANTHROPIC_API_KEY=sk-ant-xxxxx" >> .env

uvicorn app.main:app --reload
```

### Frontend

```bash
# Terminal 2 - Frontend
cd frontend
npm install
npm run dev
```

### Access
- Frontend: http://localhost:5173
- Backend: http://localhost:8000

---

## Try It Out

Copy and paste this example workout:

```
AMRAP 20min:
10 Wall Balls (20/14 lbs)
10 Box Jumps (24/20 in)
10 Burpees
```

Click "Generate Timer" and watch the AI parse it into a fully functional timer!

---

## Example Workouts to Try

### Fran (For Time)
```
For Time:
21-15-9 reps of:
Thrusters (95/65 lbs)
Pull-ups
```

### EMOM
```
EMOM 12min:
5 Power Cleans (135/95 lbs)
10 Push-ups
```

### Tabata
```
Tabata:
Air Squats
(20 seconds work / 10 seconds rest for 8 rounds)
```

### Chipper
```
For Time:
100 Double Unders
75 Air Squats
50 Sit-ups
25 Burpees
```

---

## Troubleshooting

### Docker Issues

**Port already in use:**
```bash
# Stop other services using ports 5173, 8000, 5432, 6379
docker-compose down
docker-compose up
```

**Rebuild containers:**
```bash
docker-compose up --build
```

### Manual Setup Issues

**Backend won't start:**
- Check Python version: `python --version` (need 3.11+)
- Make sure virtual environment is activated
- Verify API key in `.env` file

**Frontend won't start:**
- Check Node version: `node --version` (need 18+)
- Try deleting `node_modules` and running `npm install` again

**API key error:**
- Make sure you added your Anthropic API key to `backend/.env`
- Key should start with `sk-ant-`

---

## Next Steps

1. Customize the timer audio cues in [backend/app/services/ai_service.py](backend/app/services/ai_service.py)
2. Add your own workout examples in [frontend/src/components/WorkoutInput.vue](frontend/src/components/WorkoutInput.vue)
3. Explore the API at http://localhost:8000/api/v1/docs

Enjoy your workouts!
