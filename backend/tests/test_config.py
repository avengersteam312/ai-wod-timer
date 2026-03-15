"""
Tests for app.config.Settings, especially BACKEND_CORS_ORIGINS parsing from env.
Pydantic v2 does not auto-parse JSON env vars; we use a field_validator.
"""

import pytest

from app.config import Settings


class TestBackendCorsOrigins:
    """BACKEND_CORS_ORIGINS must accept JSON string from .env and default list."""

    def test_default_is_list(self):
        # No override: default list is used (validator receives list, returns as-is)
        s = Settings()
        assert isinstance(s.BACKEND_CORS_ORIGINS, list)
        assert "http://localhost:5173" in s.BACKEND_CORS_ORIGINS

    def test_json_string_parsed_from_env(self):
        # Simulates .env: BACKEND_CORS_ORIGINS=["http://localhost:5173","https://app.example.com"]
        s = Settings(
            BACKEND_CORS_ORIGINS='["http://localhost:5173","https://app.example.com"]'
        )
        assert s.BACKEND_CORS_ORIGINS == [
            "http://localhost:5173",
            "https://app.example.com",
        ]

    def test_json_string_single_origin(self):
        s = Settings(BACKEND_CORS_ORIGINS='["http://localhost:5173"]')
        assert s.BACKEND_CORS_ORIGINS == ["http://localhost:5173"]

    def test_empty_json_array(self):
        s = Settings(BACKEND_CORS_ORIGINS="[]")
        assert s.BACKEND_CORS_ORIGINS == []

    def test_comma_separated_fallback(self):
        # Non-JSON fallback: comma-separated list
        s = Settings(BACKEND_CORS_ORIGINS="http://a.com,http://b.com")
        assert s.BACKEND_CORS_ORIGINS == ["http://a.com", "http://b.com"]

    def test_non_string_elements_rejected(self):
        # JSON array of non-strings is rejected
        with pytest.raises(ValueError, match="must be a list of strings"):
            Settings(BACKEND_CORS_ORIGINS="[1, 2, 3]")
