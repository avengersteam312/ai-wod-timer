"""
FastAPI dependencies for authentication and authorization.
"""

import logging
from fastapi import Depends, HTTPException, status, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.services.supabase_auth import verify_supabase_token
from typing import Optional

logger = logging.getLogger(__name__)
security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """
    Dependency to get the current authenticated user.

    Extracts the Supabase token from the Authorization header,
    verifies it, and returns the decoded token with user info.

    Usage in endpoints:
        @router.get("/protected")
        async def protected_route(current_user: dict = Depends(get_current_user)):
            return {"user_id": current_user["sub"]}
    """
    token = credentials.credentials

    try:
        decoded_token = await verify_supabase_token(token)
        return decoded_token
    except ValueError as e:
        logger.warning(f"Token verification failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        logger.error(f"Unexpected error during token verification: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Authentication service error",
        )


async def get_current_user_optional(
    authorization: Optional[str] = Header(None),
) -> Optional[dict]:
    """
    Optional authentication dependency.
    Returns user if authenticated, None if not.
    """
    if not authorization or not authorization.startswith("Bearer "):
        return None

    try:
        parts = authorization.split("Bearer ", 1)
        if len(parts) < 2:
            return None

        token = parts[1].strip()
        if not token:
            return None

        decoded_token = await verify_supabase_token(token)
        return decoded_token
    except ValueError:
        return None
    except Exception as e:
        logger.warning(
            f"Unexpected error during optional token verification: {e}", exc_info=True
        )
        return None
