import os
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor


def configure_metrics() -> None:
    """
    Set up OTel MeterProvider with OTLP push to Grafana Cloud Mimir.

    Call once in main.py BEFORE metrics.py is imported — meters are bound to
    whatever provider is active at import time.
    No-op when OTEL_EXPORTER_OTLP_ENDPOINT is unset (local dev).
    """
    otlp_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
    if not otlp_endpoint:
        return

    from opentelemetry import metrics as metrics_api
    from opentelemetry.sdk.metrics import MeterProvider
    from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
    from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter

    exporter = OTLPMetricExporter()
    # Push every 30s — balances freshness vs Grafana Cloud free-tier cardinality
    reader = PeriodicExportingMetricReader(exporter, export_interval_millis=30_000)
    provider = MeterProvider(metric_readers=[reader])
    metrics_api.set_meter_provider(provider)


def configure_tracing(app) -> None:
    """Call once in main.py — never instantiate TracerProvider anywhere else."""
    otlp_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
    if not otlp_endpoint:
        # No endpoint configured — tracing is a no-op (safe for local dev)
        return

    provider = TracerProvider()
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(provider)
    FastAPIInstrumentor.instrument_app(app)
    HTTPXClientInstrumentor().instrument()  # auto-traces OpenAI + Supabase HTTP calls
