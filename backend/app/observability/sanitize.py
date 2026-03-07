import re

_REDACT_PATTERN = re.compile(
    r"(password|token|secret|authorization|api_key|jwt|bearer)",
    re.IGNORECASE,
)
_REDACTED = "[REDACTED]"


class SanitizingProcessor:
    """structlog processor — strips sensitive values before any log emission."""

    def __call__(self, logger, method, event_dict: dict) -> dict:
        for key in list(event_dict.keys()):
            if _REDACT_PATTERN.search(key):
                event_dict[key] = _REDACTED
        return event_dict
