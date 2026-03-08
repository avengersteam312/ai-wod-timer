# Project Structure

Complete overview of the AI Workout Timer application architecture.

## Directory Tree

```
ai-wod-app/
├── backend/                          # FastAPI Python backend
│   ├── app/
│   │   ├── api/
│   │   │   └── v1/
│   │   │       ├── endpoints/
│   │   │       │   └── timer.py      # Timer API endpoints
│   │   │       └── router.py         # API router configuration
│   │   ├── models/                   # SQLAlchemy database models (future)
│   │   ├── schemas/
│   │   │   └── workout.py            # Pydantic request/response models
│   │   ├── services/
│   │   │   ├── ai_service.py         # AI integration (Claude)
│   │   │   └── workout_parser.py     # Workout parsing logic
│   │   ├── config.py                 # Application configuration
│   │   └── main.py                   # FastAPI application entry
│   ├── tests/                        # Backend tests (future)
│   ├── .env                          # Environment variables
│   ├── .env.example                  # Example environment file
│   ├── Dockerfile                    # Backend container config
│   └── requirements.txt              # Python dependencies
│
├── frontend/                         # Vue 3 + TypeScript frontend
│   ├── src/
│   │   ├── components/
│   │   │   ├── ui/                   # Reusable UI components
│   │   │   │   ├── Button.vue        # Button component (CVA variants)
│   │   │   │   ├── Card.vue          # Card container
│   │   │   │   └── Textarea.vue      # Textarea input
│   │   │   ├── timer/                # Timer-specific components
│   │   │   │   ├── TimerDisplay.vue  # Main timer display
│   │   │   │   ├── TimerControls.vue # Play/pause/reset controls
│   │   │   │   └── MovementList.vue  # Workout movements display
│   │   │   └── WorkoutInput.vue      # Workout input form
│   │   ├── composables/
│   │   │   ├── useTimer.ts           # Timer logic composable
│   │   │   └── useAudio.ts           # Audio cues composable
│   │   ├── lib/
│   │   │   └── utils.ts              # Utility functions (cn, formatTime)
│   │   ├── router/
│   │   │   └── index.ts              # Vue Router configuration
│   │   ├── services/
│   │   │   └── api.ts                # API client (Axios)
│   │   ├── stores/
│   │   │   ├── workoutStore.ts       # Workout state (Pinia)
│   │   │   └── timerStore.ts         # Timer state (Pinia)
│   │   ├── types/
│   │   │   └── workout.ts            # TypeScript type definitions
│   │   ├── views/
│   │   │   └── TimerView.vue         # Main timer page
│   │   ├── App.vue                   # Root component
│   │   ├── main.ts                   # Application entry
│   │   └── style.css                 # Global styles (Tailwind)
│   ├── public/                       # Static assets
│   ├── Dockerfile                    # Frontend container config
│   ├── package.json                  # NPM dependencies
│   ├── tailwind.config.js            # Tailwind configuration
│   ├── tsconfig.json                 # TypeScript configuration
│   └── vite.config.ts                # Vite build configuration
│
├── docker-compose.yml                # Multi-container orchestration
├── .gitignore                        # Git ignore patterns
├── README.md                         # Main documentation
├── QUICKSTART.md                     # Quick start guide
└── PROJECT_STRUCTURE.md              # This file
```

## Key Components

### Backend Architecture

#### 1. API Layer (`app/api/v1/`)
- **timer.py**: REST endpoints for workout parsing
  - `POST /api/v1/timer/parse` - Parse workout and generate timer
  - `GET /api/v1/timer/health` - Health check

#### 2. Services Layer (`app/services/`)
- **ai_service.py**: Integrates with Anthropic Claude API
  - Sends workout text to AI model
  - Parses JSON response
  - Generates audio cues

- **workout_parser.py**: Orchestrates workout parsing
  - Calls AI service
  - Converts AI response to schema
  - Returns ParsedWorkout object

#### 3. Schemas (`app/schemas/`)
- **workout.py**: Pydantic models for validation
  - `WorkoutType`: Enum for workout types
  - `Movement`: Individual exercise representation
  - `TimerConfig`: Timer configuration
  - `ParsedWorkout`: Complete parsed workout
  - `AudioCue`: Audio announcement definition

### Frontend Architecture

#### 1. Components

**UI Components** (`components/ui/`)
- Reusable, composable components built with CVA (Class Variance Authority)
- Styled with Tailwind CSS
- Type-safe props with TypeScript

**Feature Components** (`components/timer/`)
- **TimerDisplay**: Shows countdown/count-up timer
  - Large font display
  - Color changes based on time remaining
  - Progress bar visualization

- **TimerControls**: Control buttons
  - Start/Pause toggle
  - Reset button
  - Audio enable/disable

- **MovementList**: Shows workout breakdown
  - Displays movements with reps/duration
  - Shows workout type and rounds
  - AI interpretation note

**Page Components**
- **WorkoutInput**: Input form for workout text
  - Textarea for workout entry
  - Example workout buttons
  - Parse and generate timer

#### 2. State Management (Pinia Stores)

**workoutStore**
- Current workout state
- Loading states
- Error handling
- API integration

**timerStore**
- Timer state (idle/running/paused/completed)
- Current time tracking
- Round/interval tracking
- Timer controls (start/pause/reset)

#### 3. Composables

**useTimer**
- Timer interval management
- Audio cue triggering
- Completion detection
- Auto-cleanup on unmount

**useAudio**
- Speech synthesis for announcements
- Beep generation for alerts
- Audio enable/disable toggle

#### 4. Services

**api.ts**
- Axios HTTP client
- API endpoint wrappers
- Request/response typing

### Data Flow

```
User Input → WorkoutInput Component
    ↓
    → workoutStore.parseWorkout()
    ↓
    → API Service (POST /api/v1/timer/parse)
    ↓
    → Backend: WorkoutParser.parse()
    ↓
    → AI Service (Claude API)
    ↓
    → Response: ParsedWorkout
    ↓
    → timerStore.setConfig()
    ↓
    → TimerView displays timer
    ↓
User clicks Start → useTimer composable
    ↓
    → setInterval (1 second)
    ↓
    → Update timerStore.currentTime
    ↓
    → Check audio cues → useAudio.speak()
    ↓
    → Update UI (TimerDisplay, progress bar)
```

## Technology Choices Explained

### Why FastAPI?
- Async/await support for better performance
- Automatic OpenAPI documentation
- Modern Python 3.11+ features
- Type hints with Pydantic
- Easy to extend for future features

### Why Vue 3 Composition API?
- Better TypeScript support than Options API
- More modular and reusable code
- Easier to test individual composables
- Better performance with reactivity

### Why Radix Vue?
- Unstyled, accessible components
- Full keyboard navigation support
- Built on WAI-ARIA standards
- Highly customizable with Tailwind

### Why Pinia over Vuex?
- Simpler API (no mutations)
- Better TypeScript inference
- Modular by design
- Composition API friendly

### Why Anthropic Claude?
- Excellent at structured output (JSON)
- Understands fitness terminology
- Reliable parsing of varied input formats
- Good at following system prompts

## Scalability Considerations

### Current MVP
- Single-instance backend
- No database persistence (stateless)
- In-memory state

### Future Growth Path
1. **Add PostgreSQL models**: User accounts, workout history
2. **Redis caching**: Cache AI responses for common workouts
3. **Horizontal scaling**: Multiple backend instances behind load balancer
4. **CDN**: Static asset distribution
5. **WebSockets**: Real-time features (live leaderboards, shared workouts)

## Configuration Files

### Backend
- **config.py**: Centralized configuration using Pydantic Settings
- **.env**: Environment-specific variables (API keys, DB URLs)
- **requirements.txt**: Python package dependencies

### Frontend
- **vite.config.ts**: Build tool configuration, proxy setup
- **tailwind.config.js**: Design system configuration
- **tsconfig.json**: TypeScript compiler options
- **package.json**: NPM scripts and dependencies

### Infrastructure
- **docker-compose.yml**: Multi-service orchestration
- **Dockerfile** (backend): Python container setup
- **Dockerfile** (frontend): Node container setup

## Development Workflow

1. **Local Development**:
   - Backend: `uvicorn app.main:app --reload`
   - Frontend: `npm run dev`

2. **Docker Development**:
   - `docker-compose up` (auto-reload enabled)

3. **API Testing**:
   - Interactive docs: http://localhost:8000/api/v1/docs
   - Manual testing with curl/Postman

4. **Frontend Development**:
   - Hot module reload (HMR) with Vite
   - Vue DevTools for debugging

## Future Expansion Points

### Backend
- `app/models/`: Add SQLAlchemy models for persistence
- `app/tests/`: Unit and integration tests
- `app/api/v1/endpoints/`: Add user, history, integration endpoints
- `app/services/`: Add external API integrations

### Frontend
- `src/components/`: Add workout editor, history viewer
- `src/views/`: Add dashboard, profile, settings pages
- `src/stores/`: Add user store, history store
- `src/services/`: Add integration services (BTWB, SugarWOD)

## Module Reusability

Following your principle of modularity and reusability:

### Reusable Modules
- **UI Components**: Can be extracted to a shared component library
- **useTimer composable**: Can be used in any timing application
- **useAudio composable**: Reusable for any audio feedback needs
- **API client pattern**: Template for other services
- **Pinia stores**: Modular state management, easy to split

### Composition Over Inheritance
- Components composed from smaller UI elements
- Composables combine to create complex behaviors
- Services are injected, not extended
- Clear separation of concerns

This structure allows for easy testing, maintenance, and future expansion!
