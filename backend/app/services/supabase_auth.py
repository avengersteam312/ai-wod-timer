"""
Supabase JWT verification service.
Verifies access tokens sent from the Flutter app.
"""
import jwt
import structlog
from app.config import settings
from app.observability.security import log_security_event

log = structlog.get_logger(__name__)


def verify_supabase_token(token: str) -> dict:
    """
    Verify a Supabase JWT access token and return the decoded payload.

    Args:
        token: Supabase access token string

    Returns:
        Decoded token containing user information (sub, email, etc.)

    Raises:
        ValueError: If token is invalid or expired
    """
    if not token or not isinstance(token, str):
        raise ValueError("Token is required and must be a string")

    if not settings.SUPABASE_JWT_SECRET:
        raise ValueError("SUPABASE_JWT_SECRET is not configured")

    try:
        decoded = jwt.decode(
            token,
            settings.SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            audience="authenticated",
        )
        return decoded
    except jwt.ExpiredSignatureError:
        log.warning("auth.token_expired")
        log_security_event("auth.failure", ip="unknown", detail="token_expired")
        raise ValueError("Token has expired")
    except jwt.InvalidTokenError as e:
        log.warning("auth.token_invalid", reason=str(e))
        log_security_event("auth.failure", ip="unknown", detail="invalid_token")
        raise ValueError("Invalid token")
