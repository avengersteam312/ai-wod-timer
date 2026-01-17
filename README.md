# AI Workout Timer

An intelligent workout timer application powered by AI that parses CrossFit and functional fitness workouts to generate smart, context-aware timers with audio cues.

## Features

### MVP (Current)
- **AI Workout Parsing**: Paste any workout text and let AI understand the structure
- **Smart Timer Generation**: Automatically creates appropriate timers for different workout types
  - AMRAP (As Many Rounds As Possible)
  - EMOM (Every Minute On the Minute)
  - For Time
  - Tabata (20s work / 10s rest)
  - Rounds with rest
  - Custom intervals
- **Audio Cues**: Voice announcements for:
  - Start countdown (3-2-1-GO)
  - Time warnings (halfway, 5min, 1min, 30s, 10s)
  - Completion
- **Visual Progress**: Large timer display with progress bar
- **Movement Tracking**: See your workout broken down by movements

### Planned Features
- Create and save custom workouts
- Workout history and logging
- API integrations with third-party services (BTWB, SugarWOD, etc.)
- Performance analytics
- User accounts and profiles

## Tech Stack

### Backend
- **Python 3.11+** with FastAPI
- **Anthropic Claude API** for AI workout parsing
- **PostgreSQL** for data persistence
- **Redis** for caching
- **SQLAlchemy** ORM
- **Pydantic** for validation

### Frontend
- **Vue 3** with Composition API
- **TypeScript** for type safety
- **Vite** as build tool
- **Radix Vue** component library
- **TailwindCSS** for styling
- **Pinia** for state management
- **Vue Router** for navigation

### Infrastructure
- **Docker** & **Docker Compose** for containerization
- **Uvicorn** ASGI server

## Getting Started

### Prerequisites
- Docker and Docker Compose (recommended)
- OR:
  - Python 3.11+
  - Node.js 18+
  - PostgreSQL 15+
  - Redis

### Quick Start with Docker

1. Clone the repository:
```bash
git clone <repository-url>
cd ai-wod-app
```

2. Create environment file:
```bash
cp backend/.env.example backend/.env
```

3. Add your Anthropic API key to `backend/.env`:
```env
ANTHROPIC_API_KEY=your_api_key_here
```

4. Start all services:
```bash
docker-compose up
```

5. Access the application:
- Frontend: http://localhost:5173
- Backend API: http://localhost:8000
- API Docs: http://localhost:8000/api/v1/docs

### Manual Setup (Without Docker)

#### Backend Setup

1. Navigate to backend directory:
```bash
cd backend
```

2. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. Install dependencies:
```bash
pip install -r requirements.txt
```

4. Create `.env` file:
```bash
cp .env.example .env
```

5. Add your API key and configure database in `.env`

6. Start the server:
```bash
uvicorn app.main:app --reload
```

Backend will be available at http://localhost:8000

#### Frontend Setup

1. Navigate to frontend directory:
```bash
cd frontend
```

2. Install dependencies:
```bash
npm install
```

3. Start development server:
```bash
npm run dev
```

Frontend will be available at http://localhost:5173

## Usage

1. **Enter a Workout**: Paste or type your workout in the text area. Examples:
   ```
   AMRAP 20min:
   10 Wall Balls (20/14 lbs)
   10 Box Jumps (24/20 in)
   10 Burpees
   ```

2. **Generate Timer**: Click "Generate Timer" to parse the workout with AI

3. **Start Training**: Use the timer controls:
   - Play/Pause: Start or pause the timer
   - Reset: Reset timer to beginning
   - Audio toggle: Enable/disable voice cues

4. **Track Progress**: Watch the timer countdown and see your movements highlighted

## API Documentation

Once running, visit http://localhost:8000/api/v1/docs for interactive API documentation.

### Key Endpoints

#### POST `/api/v1/timer/parse`
Parse workout text and generate timer configuration.

**Request:**
```json
{
  "workout_text": "AMRAP 20min:\n10 Wall Balls\n10 Box Jumps\n10 Burpees"
}
```

**Response:**
```json
{
  "workout_type": "amrap",
  "duration": 1200,
  "movements": [
    {"name": "Wall Balls", "reps": 10},
    {"name": "Box Jumps", "reps": 10},
    {"name": "Burpees", "reps": 10}
  ],
  "timer_config": {
    "type": "countdown",
    "total_seconds": 1200,
    "audio_cues": [...]
  }
}
```

## Project Structure

```
ai-wod-app/
├── backend/
│   ├── app/
│   │   ├── api/v1/          # API endpoints
│   │   ├── services/        # Business logic
│   │   ├── models/          # Database models
│   │   └── schemas/         # Pydantic schemas
│   ├── tests/
│   └── requirements.txt
├── frontend/
│   ├── src/
│   │   ├── components/      # Vue components
│   │   ├── views/           # Page views
│   │   ├── stores/          # Pinia stores
│   │   ├── composables/     # Composition functions
│   │   └── services/        # API client
│   └── package.json
└── docker-compose.yml
```

## Configuration

### Environment Variables

Backend (`.env`):
```env
# AI Service
ANTHROPIC_API_KEY=your_key_here
AI_PROVIDER=anthropic
AI_MODEL=claude-3-5-sonnet-20241022

# Database
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/ai_workout

# Redis
REDIS_URL=redis://localhost:6379/0

# CORS
BACKEND_CORS_ORIGINS=["http://localhost:5173"]
```

## Development

### Running Tests

Backend:
```bash
cd backend
pytest
```

Frontend:
```bash
cd frontend
npm run test
```

### Building for Production

Frontend:
```bash
cd frontend
npm run build
```

Backend is production-ready with:
```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```

## Contributing

This is currently a personal project, but contributions are welcome!

## License

MIT

## Roadmap

### Phase 1: MVP (Current)
- [x] AI-powered workout parsing
- [x] Smart timer generation
- [x] Audio cues
- [x] Basic UI

### Phase 2: Core Features
- [ ] User authentication
- [ ] Workout creation and editing
- [ ] Save workouts to database
- [ ] Workout history

### Phase 3: Advanced Features
- [ ] API integrations (BTWB, SugarWOD)
- [ ] Performance tracking
- [ ] Analytics dashboard
- [ ] Mobile responsive design improvements

### Phase 4: Community
- [ ] Share workouts
- [ ] Leaderboards
- [ ] Social features

## Support

For issues or questions, please open an issue on GitHub.
