import json

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List, Union


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        case_sensitive=True,
    )

    # API Configuration
    API_V1_PREFIX: str = "/api/v1"
    PROJECT_NAME: str = "AI Workout Timer"
    DEBUG: bool = True

    # AI Service
    OPENAI_API_KEY: str = ""
    AI_PROVIDER: str = "openai"
    AI_MODEL: str = "gpt-4o-mini"  # Low-latency model for workout parsing
    AI_VISION_MODEL: str = "gpt-4o-mini"  # Model for image text extraction
    AI_CLASSIFIER_MODEL: str = "gpt-4.1-mini"  # Fast, cheap model for classification
    USE_AGENT_WORKFLOW: bool = False  # Set to True to use OpenAI Agents SDK workflow
    USE_CUSTOM_PROMPT_ONLY: bool = False  # Enable type-specific prompts for faster parsing (60-78% token reduction)

    # Database
    DATABASE_URL: str = "postgresql://postgres:postgres@localhost:5432/ai_workout"
    TEST_DATABASE_URL: str = (
        "postgresql://postgres:postgres@localhost:5432/ai_workout_test"
    )

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # CORS — allow browser clients (Flutter web, Vite, etc.). Override in .env for production.
    # In .env use a JSON array, e.g. BACKEND_CORS_ORIGINS=["http://localhost:5173"]
    BACKEND_CORS_ORIGINS: List[str] = [
        "http://localhost:5173",
        "http://localhost:3000",
        "http://localhost:8080",
        "http://127.0.0.1:5173",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080",
    ]

    @field_validator("BACKEND_CORS_ORIGINS", mode="before")
    @classmethod
    def parse_cors_origins(cls, v: Union[str, list]) -> list:
        """Parse BACKEND_CORS_ORIGINS from JSON string when loaded from .env."""
        if isinstance(v, list):
            return v
        if isinstance(v, str):
            v = v.strip()
            if not v:
                return []
            try:
                parsed = json.loads(v)
            except json.JSONDecodeError:
                # Fallback: comma-separated list (no spaces in .env value)
                parsed = [origin.strip() for origin in v.split(",") if origin.strip()]
            if isinstance(parsed, list) and all(isinstance(x, str) for x in parsed):
                return parsed
            raise ValueError("BACKEND_CORS_ORIGINS must be a list of strings")
        raise ValueError("BACKEND_CORS_ORIGINS must be a string or list")

    # Supabase
    SUPABASE_URL: str = ""  # e.g. https://<ref>.supabase.co
    SUPABASE_ANON_KEY: str = ""  # Public anon key — used to call auth/v1/user
    SUPABASE_JWT_SECRET: str = ""  # Kept for reference; no longer used for verification

    # Observability
    SENTRY_DSN: str = ""
    ENV: str = "development"
    GRAFANA_CLOUD_LOKI_URL: str = ""
    GRAFANA_CLOUD_LOKI_USER: str = ""
    GRAFANA_CLOUD_LOKI_API_KEY: str = ""
    OTEL_EXPORTER_OTLP_ENDPOINT: str = ""
    OTEL_EXPORTER_OTLP_HEADERS: str = ""


settings = Settings()
