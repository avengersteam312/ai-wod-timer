"""
Supabase token verification service.
Verifies access tokens by calling Supabase's /auth/v1/user REST endpoint.
This approach is immune to JWT algorithm changes (HS256 → ES256 rotation, etc.).
"""

import httpx
import structlog
from app.config import settings
from app.observability.security import log_security_event

log = structlog.get_logger(__name__)


async def verify_supabase_token(token: str) -> dict:
    """
    Verify a Supabase access token by calling the Supabase REST API.

    Args:
        token: Supabase access token string

    Returns:
        Dict with user info: {"sub": user_id, "email": email}

    Raises:
        ValueError: If token is invalid, expired, or Supabase is unreachable
    """
    if not token or not isinstance(token, str):
        raise ValueError("Token is required and must be a string")

    if not settings.SUPABASE_URL:
        raise ValueError("SUPABASE_URL is not configured")

    if not settings.SUPABASE_ANON_KEY:
        raise ValueError("SUPABASE_ANON_KEY is not configured")

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                f"{settings.SUPABASE_URL}/auth/v1/user",
                headers={
                    "Authorization": f"Bearer {token}",
                    "apikey": settings.SUPABASE_ANON_KEY,
                },
            )

        if response.status_code == 401:
            log.warning("auth.token_invalid", status=401)
            log_security_event(
                "auth.failure", ip="unknown", detail="token_rejected_by_supabase"
            )
            raise ValueError("Invalid or expired token")

        if response.status_code != 200:
            log.warning("auth.supabase_error", status=response.status_code)
            raise ValueError(f"Supabase auth error: {response.status_code}")

        user = response.json()
        return {
            "sub": user["id"],
            "email": user.get("email", ""),
        }

    except httpx.TimeoutException:
        log.error("auth.supabase_timeout")
        raise ValueError("Auth service timeout")
    except httpx.RequestError as e:
        log.error("auth.supabase_unreachable", error=str(e))
        raise ValueError("Auth service unreachable")
