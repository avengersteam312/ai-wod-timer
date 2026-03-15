import os
import sys
import types


# Keep tests independent from developer-local backend/.env values.
os.environ["DEBUG"] = "true"
os.environ.setdefault("OPENAI_API_KEY", "test-openai-key")
os.environ.setdefault("SUPABASE_URL", "https://example.supabase.co")
os.environ.setdefault("SUPABASE_ANON_KEY", "test-anon-key")
os.environ.setdefault("SUPABASE_JWT_SECRET", "test-jwt-secret")


if "structlog" not in sys.modules:
    configured_processors = []

    class _BoundLogger:
        def __init__(self, name=None):
            self.name = name

        def info(self, event, **kwargs):
            return _emit("info", event, kwargs)

        def warning(self, event, **kwargs):
            return _emit("warning", event, kwargs)

        def error(self, event, **kwargs):
            return _emit("error", event, kwargs)

    def _emit(level: str, event: str, kwargs: dict):
        event_dict = {"event": event, **kwargs}
        current = event_dict
        for processor in configured_processors:
            current = processor(None, level, current)
        return current

    def _configure(
        processors=None,
        wrapper_class=None,
        logger_factory=None,
        cache_logger_on_first_use=False,
    ):
        del wrapper_class, logger_factory, cache_logger_on_first_use
        configured_processors[:] = list(processors or [])

    def _get_logger(name=None):
        return _BoundLogger(name)

    def _add_log_level(logger, method, event_dict):
        del logger
        event_dict.setdefault("log_level", method)
        return event_dict

    class _JSONRenderer:
        def __call__(self, logger, method, event_dict):
            del logger, method
            return event_dict

    structlog_stub = types.SimpleNamespace(
        configure=_configure,
        get_logger=_get_logger,
        make_filtering_bound_logger=lambda level: _BoundLogger,
        ReturnLoggerFactory=lambda: object(),
        stdlib=types.SimpleNamespace(add_log_level=_add_log_level),
        processors=types.SimpleNamespace(JSONRenderer=_JSONRenderer),
    )
    sys.modules["structlog"] = structlog_stub


if "opentelemetry" not in sys.modules:

    class _Metric:
        def add(self, value, attributes=None):
            del value, attributes

        def record(self, value, attributes=None):
            del value, attributes

    class _Meter:
        def create_counter(self, name, description=""):
            del name, description
            return _Metric()

        def create_histogram(self, name, description="", unit=""):
            del name, description, unit
            return _Metric()

    otel_metrics_module = types.ModuleType("opentelemetry.metrics")
    otel_metrics_module.get_meter = lambda name: _Meter()

    otel_module = types.ModuleType("opentelemetry")
    otel_module.metrics = otel_metrics_module

    sys.modules["opentelemetry"] = otel_module
    sys.modules["opentelemetry.metrics"] = otel_metrics_module
