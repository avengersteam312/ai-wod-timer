import os
import structlog
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

_log = structlog.get_logger(__name__)


def _otlp_headers() -> dict:
    """Parse OTEL_EXPORTER_OTLP_HEADERS env var into a dict for HTTP exporter."""
    raw = os.getenv("OTEL_EXPORTER_OTLP_HEADERS", "")
    headers = {}
    for pair in raw.split(","):
        if "=" in pair:
            k, v = pair.split("=", 1)
            headers[k.strip()] = v.strip()
    return headers


def _masked_headers() -> str:
    """Return a safe representation of OTEL_EXPORTER_OTLP_HEADERS for logging."""
    raw = os.getenv("OTEL_EXPORTER_OTLP_HEADERS", "")
    if not raw:
        return "<not set>"
    # Show key names and first/last 4 chars of each value — enough to spot mistakes
    parts = []
    for pair in raw.split(","):
        if "=" in pair:
            k, v = pair.split("=", 1)
            masked = v[:4] + "..." + v[-4:] if len(v) > 8 else "****"
            parts.append(f"{k.strip()}={masked}")
    return ", ".join(parts) or "<malformed>"


def configure_metrics() -> None:
    """
    Set up OTel MeterProvider with OTLP/HTTP push to Grafana Cloud Mimir.

    Call once in main.py BEFORE metrics.py is imported — meters are bound to
    whatever provider is active at import time.
    No-op when OTEL_EXPORTER_OTLP_ENDPOINT is unset (local dev).
    """
    otlp_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
    if not otlp_endpoint:
        _log.info("otlp.metrics.disabled", reason="OTEL_EXPORTER_OTLP_ENDPOINT not set")
        return
    _log.info("otlp.metrics.configured", endpoint=otlp_endpoint, headers=_masked_headers())

    from opentelemetry import metrics as metrics_api
    from opentelemetry.sdk.metrics import MeterProvider
    from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
    from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter

    exporter = OTLPMetricExporter(
        endpoint=f"{otlp_endpoint}/v1/metrics",
        headers=_otlp_headers(),
    )
    reader = PeriodicExportingMetricReader(exporter, export_interval_millis=30_000)
    provider = MeterProvider(metric_readers=[reader])
    metrics_api.set_meter_provider(provider)


def configure_tracing(app) -> None:
    """Call once in main.py — never instantiate TracerProvider anywhere else."""
    otlp_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
    if not otlp_endpoint:
        _log.info("otlp.tracing.disabled", reason="OTEL_EXPORTER_OTLP_ENDPOINT not set")
        return
    _log.info("otlp.tracing.configured", endpoint=otlp_endpoint, headers=_masked_headers())

    provider = TracerProvider()
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(
        endpoint=f"{otlp_endpoint}/v1/traces",
        headers=_otlp_headers(),
    )))
    trace.set_tracer_provider(provider)
    FastAPIInstrumentor.instrument_app(app)
    HTTPXClientInstrumentor().instrument()
