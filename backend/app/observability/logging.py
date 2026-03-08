import os
import json
import time
import threading
from queue import Queue, Empty

import structlog
import httpx

from app.observability.sanitize import SanitizingProcessor


class _LokiShipper:
    """
    Non-blocking Loki log shipper.

    Batches log entries in a daemon thread and POSTs to Grafana Cloud Loki's
    push API using httpx. Never blocks the request path — failures are silently
    dropped to protect app availability.
    """

    def __init__(self, url: str, user: str, api_key: str, labels: dict) -> None:
        import re

        _base = re.sub(r"/loki/api/v1/push$", "", url.rstrip("/"))
        self._url = f"{_base}/loki/api/v1/push"
        self._auth = (user, api_key)
        self._labels = labels
        self._queue: Queue = Queue(maxsize=2000)
        t = threading.Thread(target=self._worker, daemon=True)
        t.start()

    def processor(self):
        """Return a structlog processor that queues each log entry for shipping."""
        shipper = self

        def _process(logger, method, event_dict: dict) -> dict:
            try:
                shipper._queue.put_nowait(
                    {
                        "ts": str(int(time.time_ns())),
                        "line": json.dumps(event_dict),
                    }
                )
            except Exception:
                pass  # Queue full or other error — never raise from a log processor
            return event_dict

        return _process

    def _worker(self) -> None:
        with httpx.Client(auth=self._auth, timeout=5.0) as client:
            while True:
                batch: list[dict] = []
                try:
                    entry = self._queue.get(timeout=2.0)
                    batch.append(entry)
                    # Drain up to 200 more without blocking
                    while len(batch) < 200:
                        try:
                            batch.append(self._queue.get_nowait())
                        except Empty:
                            break
                except Empty:
                    continue

                payload = {
                    "streams": [
                        {
                            "stream": self._labels,
                            "values": [[e["ts"], e["line"]] for e in batch],
                        }
                    ]
                }
                try:
                    client.post(self._url, json=payload)
                except Exception:
                    pass  # Best-effort — never crash the app for log shipping


def configure_logging(log_level: str = "INFO") -> None:
    """
    Call once in main.py — never call structlog.configure() anywhere else.

    In production (GRAFANA_CLOUD_LOKI_URL set): ships logs to Loki via HTTP push
    in addition to stdout. Stdout is always present (Render captures it).
    """
    processors: list = [
        structlog.stdlib.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        SanitizingProcessor(),
    ]

    loki_url = os.getenv("GRAFANA_CLOUD_LOKI_URL")
    loki_user = os.getenv("GRAFANA_CLOUD_LOKI_USER")
    loki_key = os.getenv("GRAFANA_CLOUD_LOKI_API_KEY")
    env = os.getenv("ENV", "development")

    if loki_url and loki_user and loki_key:
        shipper = _LokiShipper(
            url=loki_url,
            user=loki_user,
            api_key=loki_key,
            labels={"job": "backend", "env": env},
        )
        processors.append(shipper.processor())

    processors.append(structlog.processors.JSONRenderer())

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.make_filtering_bound_logger(log_level),
    )
