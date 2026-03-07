import os
from fastapi import APIRouter
from app.config import settings

router = APIRouter()


@router.get("/health")
async def health():
    """
    Structured health check.

    Returns degraded status if critical config is missing.
    UptimeRobot / CI deploy gates hit this endpoint.
    """
    checks: dict[str, str] = {}

    # AI service reachability: just check the key is configured (not validity)
    checks["openai_key"] = "ok" if os.getenv("OPENAI_API_KEY") else "missing"
    checks["supabase_jwt"] = "ok" if os.getenv("SUPABASE_JWT_SECRET") else "missing"

    overall = (
        "ok"
        if all(v == "ok" for v in checks.values())
        else "degraded"
    )

    return {
        "status": overall,
        "service": settings.PROJECT_NAME,
        "checks": checks,
    }
