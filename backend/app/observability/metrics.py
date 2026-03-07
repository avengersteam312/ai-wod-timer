"""
All application metrics defined here — nowhere else.

Uses OpenTelemetry Metrics API (push via OTLP to Grafana Cloud Mimir).
configure_metrics() in tracing.py must be called before this module is imported
so meters bind to the real MeterProvider rather than the no-op default.

Call-site syntax (different from prometheus-client):
  counter.add(1, {"label": "value"})       # was: counter.labels(...).inc()
  counter.add(n, {"label": "value"})       # was: counter.labels(...).inc(n)
  histogram.record(v, {"label": "value"})  # was: histogram.labels(...).observe(v)
"""

from opentelemetry import metrics as _otel_metrics

_meter = _otel_metrics.get_meter("ai-wod-timer")

# ── HTTP ─────────────────────────────────────────────────────────────────────
http_requests_total = _meter.create_counter(
    "http_requests_total",
    description="Total HTTP requests",
)
http_request_duration = _meter.create_histogram(
    "http_request_duration_seconds",
    description="HTTP request latency in seconds",
    unit="s",
)

# ── AI pipeline — core signals ────────────────────────────────────────────────
ai_parse_requests_total = _meter.create_counter(
    "ai_parse_requests_total",
    description="Parse requests by type and model",
)
ai_parse_errors_total = _meter.create_counter(
    "ai_parse_errors_total",
    description="Parse errors by type and cause",
)
ai_parse_duration = _meter.create_histogram(
    "ai_parse_duration_seconds",
    description="Parse latency in seconds",
    unit="s",
)
ai_tokens_used_total = _meter.create_counter(
    "ai_tokens_used_total",
    description="OpenAI tokens consumed",
)
ai_classifier_confidence = _meter.create_histogram(
    "ai_classifier_confidence",
    description="Local regex classifier confidence (1.0 = local hit, 0.0 = AI fallback)",
)
ai_classifier_local_hits_total = _meter.create_counter(
    "ai_classifier_local_hits_total",
    description="Requests handled by local regex classifier (free — no OpenAI call)",
)
ai_classifier_ai_fallbacks_total = _meter.create_counter(
    "ai_classifier_ai_fallbacks_total",
    description="Requests that fell through to AI classifier (costs tokens)",
)
ai_estimated_cost_usd_total = _meter.create_counter(
    "ai_estimated_cost_usd_total",
    description="Estimated OpenAI spend in USD based on token counts and model pricing",
)

# ── Vision ────────────────────────────────────────────────────────────────────
ai_vision_requests_total = _meter.create_counter(
    "ai_vision_requests_total",
    description="Image-to-text extraction requests",
)
ai_vision_errors_total = _meter.create_counter(
    "ai_vision_errors_total",
    description="Image-to-text extraction errors",
)
ai_vision_duration = _meter.create_histogram(
    "ai_vision_duration_seconds",
    description="Image-to-text extraction latency in seconds",
    unit="s",
)

# ── Security ──────────────────────────────────────────────────────────────────
security_auth_failures_total = _meter.create_counter(
    "security_auth_failures_total",
    description="Authentication failures by IP",
)

# ── Business ──────────────────────────────────────────────────────────────────
workouts_parsed_total = _meter.create_counter(
    "workouts_parsed_total",
    description="Successfully parsed workouts by type",
)
