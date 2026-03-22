"""
Timer report endpoint for user feedback on AI parsing issues.
Anonymous submissions with IP-based rate limiting.
"""

import time
import uuid
from collections import defaultdict
from threading import Lock

import httpx
import structlog
from fastapi import APIRouter, HTTPException, Request, status

from app.config import settings
from app.schemas.report import TimerReportRequest, TimerReportResponse
from app.observability.metrics import timer_reports_total

log = structlog.get_logger(__name__)
router = APIRouter()

# In-memory rate limiter: IP -> list of timestamps
_rate_limit_store: dict[str, list[float]] = defaultdict(list)
_rate_limit_lock = Lock()
_RATE_LIMIT_WINDOW = 3600  # 1 hour in seconds
_RATE_LIMIT_MAX = 10  # Max 10 reports per IP per hour


def _get_client_ip(request: Request) -> str:
    """Extract client IP, handling proxies."""
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _check_rate_limit(ip: str) -> bool:
    """
    Check if IP is within rate limit. Returns True if allowed, False if blocked.
    Cleans up expired timestamps.
    """
    now = time.time()
    cutoff = now - _RATE_LIMIT_WINDOW

    with _rate_limit_lock:
        # Clean up expired timestamps
        _rate_limit_store[ip] = [ts for ts in _rate_limit_store[ip] if ts > cutoff]

        if len(_rate_limit_store[ip]) >= _RATE_LIMIT_MAX:
            return False

        _rate_limit_store[ip].append(now)
        return True


@router.post(
    "", response_model=TimerReportResponse, status_code=status.HTTP_201_CREATED
)
async def submit_report(request: Request, report: TimerReportRequest):
    """
    Submit an anonymous report about incorrect AI timer parsing.

    This endpoint allows users to report parsing problems without authentication.
    Rate limited to 10 reports per IP per hour.
    """
    client_ip = _get_client_ip(request)

    # Check rate limit
    if not _check_rate_limit(client_ip):
        log.warning("report.rate_limited", ip=client_ip)
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many reports. Please try again later.",
        )

    # Validate Supabase configuration
    if not settings.SUPABASE_URL or not settings.SUPABASE_ANON_KEY:
        log.error("report.supabase_not_configured")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Report service is not configured",
        )

    report_id = str(uuid.uuid4())

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                f"{settings.SUPABASE_URL}/rest/v1/timer_reports",
                headers={
                    "apikey": settings.SUPABASE_ANON_KEY,
                    "Authorization": f"Bearer {settings.SUPABASE_ANON_KEY}",
                    "Content-Type": "application/json",
                    "Prefer": "return=minimal",
                },
                json={
                    "id": report_id,
                    "report_kind": report.report_kind.value,
                    "message": report.message,
                    "original_parsed": report.original_parsed,
                    "edited_config": report.edited_config,
                    "app_version": report.app_version,
                    "platform": report.platform.value,
                },
            )

        if response.status_code not in (200, 201):
            log.error(
                "report.insert_failed",
                status=response.status_code,
                body=response.text[:500],
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to save report",
            )

        # Track metric
        timer_reports_total.add(1, {"report_kind": report.report_kind.value})

        log.info(
            "report.submitted",
            report_id=report_id,
            report_kind=report.report_kind.value,
            platform=report.platform.value,
        )

        return TimerReportResponse(id=report_id)

    except httpx.TimeoutException:
        log.error("report.supabase_timeout")
        raise HTTPException(
            status_code=status.HTTP_504_GATEWAY_TIMEOUT,
            detail="Report service timeout",
        )
    except httpx.RequestError as e:
        log.error("report.supabase_unreachable", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Report service unavailable",
        )
