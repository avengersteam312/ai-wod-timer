# System Architecture

Visual representation of the AI Workout Timer architecture.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Browser                             │
│                                                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                 Vue 3 Frontend                          │    │
│  │                                                          │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐  │    │
│  │  │ Components   │  │   Stores     │  │ Composables │  │    │
│  │  │              │  │              │  │             │  │    │
│  │  │ - Input      │  │ - Workout    │  │ - useTimer  │  │    │
│  │  │ - Timer      │  │ - Timer      │  │ - useAudio  │  │    │
│  │  │ - Controls   │  │              │  │             │  │    │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬──────┘  │    │
│  │         │                  │                  │          │    │
│  │         └──────────────────┼──────────────────┘          │    │
│  │                            │                              │    │
│  │                    ┌───────▼────────┐                    │    │
│  │                    │  API Service    │                    │    │
│  │                    │    (Axios)      │                    │    │
│  │                    └───────┬────────┘                    │    │
│  └────────────────────────────┼────────────────────────────┘    │
└─────────────────────────────────┼────────────────────────────────┘
                                  │
                                  │ HTTP/JSON
                                  │
┌─────────────────────────────────▼────────────────────────────────┐
│                      FastAPI Backend                              │
│                                                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                    API Layer                            │    │
│  │                                                          │    │
│  │  ┌──────────────────────────────────────────────────┐  │    │
│  │  │  /api/v1/timer/parse                             │  │    │
│  │  │  POST - Parse workout text                       │  │    │
│  │  └──────────────────┬───────────────────────────────┘  │    │
│  └─────────────────────┼──────────────────────────────────┘    │
│                        │                                         │
│  ┌─────────────────────▼──────────────────────────────────┐    │
│  │              Service Layer                              │    │
│  │                                                          │    │
│  │  ┌──────────────────┐       ┌────────────────────┐    │    │
│  │  │ Workout Parser   │──────▶│   AI Service       │    │    │
│  │  │                  │       │  (Claude API)      │    │    │
│  │  └──────────────────┘       └────────────────────┘    │    │
│  │                                                          │    │
│  └──────────────────────────────────────────────────────────┘    │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │              Data Layer (Future)                          │    │
│  │                                                            │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐   │    │
│  │  │  SQLAlchemy  │  │ PostgreSQL   │  │    Redis    │   │    │
│  │  │    Models    │  │   Database   │  │    Cache    │   │    │
│  │  └──────────────┘  └──────────────┘  └─────────────┘   │    │
│  └──────────────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────────┘
                                  │
                                  │ API Call
                                  │
                    ┌─────────────▼──────────────┐
                    │   Anthropic Claude API     │
                    │  (AI Workout Parser)       │
                    └────────────────────────────┘
```

## Request Flow

### Parsing a Workout

```
User Types Workout
       │
       ▼
┌──────────────────┐
│ WorkoutInput.vue │
│  Component       │
└────────┬─────────┘
         │ emit
         ▼
┌──────────────────────┐
│ workoutStore.parse() │
│  (Pinia Store)       │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│ api.parseWorkout()   │
│  (Axios Client)      │
└────────┬─────────────┘
         │ POST /api/v1/timer/parse
         ▼
┌──────────────────────────┐
│ timer.py endpoint        │
│  (FastAPI Route)         │
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│ workout_parser.parse()   │
│  (Service Layer)         │
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│ ai_service.parse()       │
│  (Claude Integration)    │
└────────┬─────────────────┘
         │ API Call
         ▼
┌──────────────────────────┐
│ Anthropic Claude API     │
└────────┬─────────────────┘
         │ JSON Response
         ▼
┌──────────────────────────┐
│ ParsedWorkout Schema     │
│  (Pydantic Model)        │
└────────┬─────────────────┘
         │ Response
         ▼
   User sees timer!
```

### Running the Timer

```
User Clicks Start
       │
       ▼
┌──────────────────────┐
│ TimerControls.vue    │
│  @click="start"      │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│ useTimer composable  │
│  startTimer()        │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│ setInterval(1000ms)  │
│  (Browser Timer)     │
└────────┬─────────────┘
         │ Every second
         ▼
┌──────────────────────────┐
│ timerStore.increment()   │
│  (Reactive State)        │
└────────┬─────────────────┘
         │
         ├──▶ Check Audio Cues ──▶ useAudio.speak()
         │
         ├──▶ Check Completion ──▶ timerStore.complete()
         │
         └──▶ Update UI ──▶ TimerDisplay.vue (auto-updates)
```

## Component Hierarchy

```
App.vue
  │
  └── RouterView
        │
        └── TimerView.vue
              │
              ├── WorkoutInput.vue (when no workout)
              │     │
              │     ├── Textarea.vue
              │     └── Button.vue (x4 examples)
              │
              └── Timer Components (when workout loaded)
                    │
                    ├── Button.vue ("New Workout")
                    │
                    ├── TimerDisplay.vue
                    │     └── Progress Bar
                    │
                    ├── TimerControls.vue
                    │     ├── Button.vue (Start/Pause)
                    │     ├── Button.vue (Reset)
                    │     └── Button.vue (Audio Toggle)
                    │
                    └── MovementList.vue
                          └── Card.vue
```

## State Management Flow

```
┌─────────────────────────────────────────────────────────┐
│                    Application State                     │
│                                                           │
│  ┌──────────────────┐         ┌────────────────────┐   │
│  │  workoutStore    │         │    timerStore      │   │
│  │  (Pinia)         │         │    (Pinia)         │   │
│  │                  │         │                    │   │
│  │ - currentWorkout │────────▶│ - config           │   │
│  │ - isLoading      │         │ - currentTime      │   │
│  │ - error          │         │ - state            │   │
│  │                  │         │ - currentRound     │   │
│  └──────────────────┘         └────────────────────┘   │
│          │                              │               │
│          │ Actions                      │ Actions       │
│          │                              │               │
│          ▼                              ▼               │
│  - parseWorkout()                - start()             │
│  - clearWorkout()                - pause()             │
│                                   - reset()             │
│                                   - incrementTime()     │
└─────────────────────────────────────────────────────────┘
           │                              │
           │                              │
           ▼                              ▼
    Components render                Components render
    automatically when                automatically when
    state changes                     state changes
```

## Data Models

### Frontend Types (TypeScript)

```typescript
// Workout Representation
interface ParsedWorkout {
  workout_type: WorkoutType
  movements: Movement[]
  rounds?: number
  duration?: number
  timer_config: TimerConfig
  raw_text: string
  ai_interpretation?: string
}

// Timer Configuration
interface TimerConfig {
  type: string
  total_seconds?: number
  intervals: Interval[]
  audio_cues: AudioCue[]
}

// Movement Definition
interface Movement {
  name: string
  reps?: number
  duration?: number
  weight?: string
}
```

### Backend Models (Python/Pydantic)

```python
# Workout Schema
class ParsedWorkout(BaseModel):
    workout_type: WorkoutType
    movements: List[Movement]
    rounds: Optional[int]
    duration: Optional[int]
    timer_config: TimerConfig
    raw_text: str
    ai_interpretation: Optional[str]

# Timer Configuration
class TimerConfig(BaseModel):
    type: str
    total_seconds: Optional[int]
    intervals: List[Interval]
    audio_cues: List[AudioCue]
```

## Technology Stack Layers

```
┌───────────────────────────────────────────────────────┐
│                  Presentation Layer                    │
│                                                         │
│  Vue 3 Components + Radix Vue + TailwindCSS           │
└───────────────────────────────────────────────────────┘
                          │
┌───────────────────────────────────────────────────────┐
│                   State Layer                          │
│                                                         │
│  Pinia Stores + Vue Router + Composables              │
└───────────────────────────────────────────────────────┘
                          │
┌───────────────────────────────────────────────────────┐
│                  Network Layer                         │
│                                                         │
│  Axios + TypeScript Types                             │
└───────────────────────────────────────────────────────┘
                          │
                     HTTP/JSON
                          │
┌───────────────────────────────────────────────────────┐
│                    API Layer                           │
│                                                         │
│  FastAPI Routes + Pydantic Validation                 │
└───────────────────────────────────────────────────────┘
                          │
┌───────────────────────────────────────────────────────┐
│                  Business Layer                        │
│                                                         │
│  Service Classes + Workout Parser                     │
└───────────────────────────────────────────────────────┘
                          │
┌───────────────────────────────────────────────────────┐
│                 Integration Layer                      │
│                                                         │
│  AI Service (Anthropic Claude SDK)                    │
└───────────────────────────────────────────────────────┘
                          │
┌───────────────────────────────────────────────────────┐
│                   Data Layer (Future)                  │
│                                                         │
│  SQLAlchemy ORM + PostgreSQL + Redis                  │
└───────────────────────────────────────────────────────┘
```

## Deployment Architecture (Future)

```
┌─────────────────────────────────────────────────────┐
│                    CDN (Static Assets)               │
│              (Cloudflare / AWS CloudFront)           │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│               Load Balancer (nginx)                  │
└────────┬──────────────────────────────┬─────────────┘
         │                               │
         ▼                               ▼
┌──────────────────┐           ┌──────────────────┐
│  Frontend Server │           │  Frontend Server │
│  (Vue 3 SPA)     │           │  (Vue 3 SPA)     │
└──────────────────┘           └──────────────────┘
         │                               │
         └───────────────┬───────────────┘
                         │
                         ▼
         ┌───────────────────────────────┐
         │   API Load Balancer (nginx)   │
         └───────────┬───────────────────┘
                     │
         ┌───────────┴───────────┐
         ▼                       ▼
┌──────────────────┐    ┌──────────────────┐
│ Backend Instance │    │ Backend Instance │
│   (FastAPI)      │    │   (FastAPI)      │
└────────┬─────────┘    └─────────┬────────┘
         │                        │
         └────────────┬───────────┘
                      │
         ┌────────────┴────────────┐
         ▼                         ▼
┌──────────────────┐    ┌──────────────────┐
│   PostgreSQL     │    │      Redis       │
│  (Primary+Rep)   │    │     (Cache)      │
└──────────────────┘    └──────────────────┘
```

## Security Considerations

```
┌─────────────────────────────────────────────────────┐
│                  Security Layers                     │
│                                                       │
│  1. HTTPS/TLS (Transport Security)                  │
│  2. CORS (Cross-Origin Protection)                  │
│  3. API Key Management (env variables)              │
│  4. Input Validation (Pydantic)                     │
│  5. Rate Limiting (Future)                          │
│  6. Authentication (Future - JWT)                   │
│  7. Database Security (Connection pooling)          │
└─────────────────────────────────────────────────────┘
```

## Performance Optimizations

### Frontend
- Vite for fast HMR
- Code splitting by route
- Lazy loading components
- Reactive state (only re-render what changes)
- Web Speech API for audio (no network needed)

### Backend
- Async FastAPI (non-blocking I/O)
- Redis caching for common workouts (future)
- Connection pooling for database (future)
- Pydantic for fast validation
- JSON response optimization

### Infrastructure
- Docker multi-stage builds (smaller images)
- Service separation (frontend/backend/db/cache)
- Volume mounting for development
- Production-ready Uvicorn workers

## Monitoring & Observability (Future)

```
┌─────────────────────────────────────────────────────┐
│                    Monitoring Stack                  │
│                                                       │
│  Logs ────▶ Elasticsearch ────▶ Kibana              │
│                                                       │
│  Metrics ──▶ Prometheus ──────▶ Grafana             │
│                                                       │
│  Traces ───▶ Jaeger/OpenTelemetry                   │
│                                                       │
│  Errors ───▶ Sentry                                  │
└─────────────────────────────────────────────────────┘
```

This architecture is designed for:
- **Scalability**: Easy to add more backend instances
- **Maintainability**: Clear separation of concerns
- **Testability**: Isolated components and services
- **Extensibility**: Ready for new features
- **Performance**: Async, cached, optimized
