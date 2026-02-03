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
    AI_MODEL: str = "gpt-4o-mini"  # Fast model for Vercel 10s timeout
    AI_CLASSIFIER_MODEL: str = "gpt-4.1-mini"  # Fast, cheap model for classification
    USE_AGENT_WORKFLOW: bool = False  # Set to True to use OpenAI Agents SDK workflow
    USE_CUSTOM_PROMPT_ONLY: bool = True  # Force using comprehensive custom prompt for all workout types

    # Database
    DATABASE_URL: str = "postgresql://postgres:postgres@localhost:5432/ai_workout"
    TEST_DATABASE_URL: str = (
        "postgresql://postgres:postgres@localhost:5432/ai_workout_test"
    )

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # CORS
    BACKEND_CORS_ORIGINS: List[str] = ["http://localhost:5173", "http://localhost:3000"]

    # Supabase
    SUPABASE_JWT_SECRET: str = ""  # Get from Supabase Dashboard > Settings > API > JWT Secret

    class Config:
        env_file = ".env"
        case_sensitive = True

        @classmethod
        def parse_env_var(cls, field_name: str, raw_val: str):
            if field_name == "BACKEND_CORS_ORIGINS":
                return json.loads(raw_val)
            return raw_val


settings = Settings()
