"""
Supabase JWT verification service.
Verifies access tokens sent from the frontend.
"""
import jwt
from app.config import settings
import logging

logger = logging.getLogger(__name__)


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
        logger.warning("Token has expired")
        raise ValueError("Token has expired")
    except jwt.InvalidTokenError as e:
        logger.warning(f"Invalid token: {e}")
        raise ValueError("Invalid token")
