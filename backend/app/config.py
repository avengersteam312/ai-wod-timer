from pydantic_settings import BaseSettings
from typing import List
import json


class Settings(BaseSettings):
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
    BACKEND_CORS_ORIGINS: List[str] = [
        "http://localhost:5173",
        "http://localhost:3000",
        "http://localhost:8080",
        "http://127.0.0.1:5173",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080",
    ]

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

    class Config:
        env_file = ".env"
        case_sensitive = True

        @classmethod
        def parse_env_var(cls, field_name: str, raw_val: str):
            if field_name == "BACKEND_CORS_ORIGINS":
                return json.loads(raw_val)
            return raw_val


settings = Settings()
