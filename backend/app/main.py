import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# ── Structured logging — must come first so all subsequent startup logs are JSON ─
from app.config import settings
from app.observability.logging import configure_logging

configure_logging(log_level="DEBUG" if settings.DEBUG else "INFO")

# ── OTel metrics provider must be configured BEFORE metrics.py is imported ──
# metrics.py calls get_meter() at module level; it must find the real provider.
from app.observability.tracing import configure_metrics, configure_tracing

configure_metrics()

import structlog

log = structlog.get_logger()

# ── App routes (imports metrics.py transitively — provider already set) ──────
from app.api.v1.router import api_router
from app.observability.health import router as health_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("app.startup", service=settings.PROJECT_NAME)
    yield
    log.info("app.shutdown", service=settings.PROJECT_NAME)


app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_PREFIX}/openapi.json",
    docs_url=f"{settings.API_V1_PREFIX}/docs",
    redoc_url=f"{settings.API_V1_PREFIX}/redoc",
    lifespan=lifespan,
)

# OTel tracing — no-op when OTEL_EXPORTER_OTLP_ENDPOINT is unset
configure_tracing(app)

# Sentry — no-op when SENTRY_DSN is unset
_sentry_dsn = os.getenv("SENTRY_DSN")
if _sentry_dsn:
    import sentry_sdk
    from sentry_sdk.integrations.fastapi import FastApiIntegration

    sentry_sdk.init(
        dsn=_sentry_dsn,
        environment=os.getenv("ENV", "production"),
        traces_sample_rate=0.1,
        integrations=[FastApiIntegration()],
    )

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.BACKEND_CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "Accept"],
    expose_headers=["Content-Type"],
)

# Health check — used by Grafana Cloud Synthetic Monitoring + CI deploy gate
app.include_router(health_router)

# API routes
app.include_router(api_router, prefix=settings.API_V1_PREFIX)


@app.get("/")
async def root():
    return {
        "message": "AI Workout Timer API",
        "docs": f"{settings.API_V1_PREFIX}/docs",
    }
