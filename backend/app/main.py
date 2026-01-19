import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.api.v1.router import api_router
from app.services.firebase_service import initialize_firebase

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup and shutdown events."""
    # Startup
    try:
        initialize_firebase()
        logger.info("Firebase Admin SDK initialized successfully")
    except Exception as e:
        # Log error but don't crash - Firebase will be initialized on first use
        logger.warning(f"Firebase initialization failed: {e}")
    
    yield
    
    # Shutdown (if needed in the future)
    # Cleanup code can go here


app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_PREFIX}/openapi.json",
    docs_url=f"{settings.API_V1_PREFIX}/docs",
    redoc_url=f"{settings.API_V1_PREFIX}/redoc",
    lifespan=lifespan,
)

# CORS middleware
# Tightened configuration: only allow necessary methods and headers
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
    expose_headers=["Content-Type"],
)

# Include API router
app.include_router(api_router, prefix=settings.API_V1_PREFIX)


@app.get("/")
async def root():
    return {
        "message": "AI Workout Timer API",
        "docs": f"{settings.API_V1_PREFIX}/docs"
    }


@app.get("/health")
async def health():
    return {"status": "healthy"}
