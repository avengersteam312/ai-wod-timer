"""
Guard test: sensitive field values must never appear in log output.
"""
import json
import structlog
from structlog.testing import capture_logs

from app.observability.sanitize import SanitizingProcessor


def _make_logger():
    structlog.configure(
        processors=[
            structlog.stdlib.add_log_level,
            SanitizingProcessor(),
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger("DEBUG"),
    )
    return structlog.get_logger()


class TestSanitizingProcessor:
    def test_password_is_redacted(self):
        processor = SanitizingProcessor()
        event = {"event": "login", "password": "super_secret_123", "log_level": "info"}
        result = processor(None, None, event)
        assert result["password"] == "[REDACTED]"

    def test_token_is_redacted(self):
        processor = SanitizingProcessor()
        event = {"event": "request", "token": "eyJhbGciOiJIUzI1NiJ9.xxx", "log_level": "info"}
        result = processor(None, None, event)
        assert result["token"] == "[REDACTED]"

    def test_api_key_is_redacted(self):
        processor = SanitizingProcessor()
        event = {"event": "call", "api_key": "sk-proj-abc123", "log_level": "info"}
        result = processor(None, None, event)
        assert result["api_key"] == "[REDACTED]"

    def test_authorization_is_redacted(self):
        processor = SanitizingProcessor()
        event = {"event": "header", "authorization": "Bearer eyJ...", "log_level": "info"}
        result = processor(None, None, event)
        assert result["authorization"] == "[REDACTED]"

    def test_jwt_is_redacted(self):
        processor = SanitizingProcessor()
        event = {"event": "verify", "jwt": "eyJhbGci...", "log_level": "info"}
        result = processor(None, None, event)
        assert result["jwt"] == "[REDACTED]"

    def test_bearer_is_redacted(self):
        processor = SanitizingProcessor()
        event = {"event": "auth", "bearer": "eyJ...", "log_level": "info"}
        result = processor(None, None, event)
        assert result["bearer"] == "[REDACTED]"

    def test_secret_is_redacted(self):
        processor = SanitizingProcessor()
        event = {"event": "config", "secret": "my_db_secret", "log_level": "info"}
        result = processor(None, None, event)
        assert result["secret"] == "[REDACTED]"

    def test_safe_fields_are_preserved(self):
        processor = SanitizingProcessor()
        event = {
            "event": "parse",
            "workout_type": "amrap",
            "user_id": "user_123",
            "duration": 20,
            "log_level": "info",
        }
        result = processor(None, None, event)
        assert result["workout_type"] == "amrap"
        assert result["user_id"] == "user_123"
        assert result["duration"] == 20

    def test_case_insensitive_matching(self):
        processor = SanitizingProcessor()
        event = {"event": "x", "PASSWORD": "hunter2", "Token": "abc", "log_level": "info"}
        result = processor(None, None, event)
        assert result["PASSWORD"] == "[REDACTED]"
        assert result["Token"] == "[REDACTED]"

    def test_partial_key_match(self):
        """Keys containing sensitive substrings (e.g. 'access_token') are also redacted."""
        processor = SanitizingProcessor()
        event = {"event": "oauth", "access_token": "tok_xxx", "log_level": "info"}
        result = processor(None, None, event)
        assert result["access_token"] == "[REDACTED]"

    def test_capture_logs_integration(self):
        """SanitizingProcessor sanitizes fields in a real structlog pipeline."""
        captured = []

        def _capture(logger, method, event_dict):
            captured.append(dict(event_dict))
            return event_dict

        structlog.configure(
            processors=[SanitizingProcessor(), _capture],
            wrapper_class=structlog.make_filtering_bound_logger("DEBUG"),
            logger_factory=structlog.ReturnLoggerFactory(),
            cache_logger_on_first_use=False,
        )
        structlog.get_logger().info("login", password="secret", user_id="u1")

        assert len(captured) == 1
        assert captured[0]["password"] == "[REDACTED]", "password leaked in log output"
        assert captured[0]["user_id"] == "u1"
