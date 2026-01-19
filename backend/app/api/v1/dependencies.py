"""
FastAPI dependencies for authentication and authorization.
"""
import logging
from fastapi import Depends, HTTPException, status, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.services.firebase_service import verify_firebase_token
from typing import Optional

logger = logging.getLogger(__name__)
security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> dict:
    """
    Dependency to get the current authenticated user.
    
    Extracts the Firebase token from the Authorization header,
    verifies it, and returns the decoded token with user info.
    
    Usage in endpoints:
        @router.get("/protected")
        async def protected_route(current_user: dict = Depends(get_current_user)):
            return {"user_id": current_user["uid"]}
    """
    token = credentials.credentials
    
    try:
        decoded_token = verify_firebase_token(token)
        return decoded_token
    except ValueError as e:
        # Log the actual error for debugging, but don't expose it to the client
        logger.warning(f"Token verification failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except Exception as e:
        # Log unexpected errors but don't expose details
        logger.error(f"Unexpected error during token verification: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Authentication service error",
        )


async def get_current_user_optional(
    authorization: Optional[str] = Header(None)
) -> Optional[dict]:
    """
    Optional authentication dependency.
    Returns user if authenticated, None if not.
    Useful for endpoints that work both with and without auth.
    
    Usage in endpoints:
        @router.get("/public")
        async def public_route(user: Optional[dict] = Depends(get_current_user_optional)):
            if user:
                return {"message": f"Hello {user['email']}"}
            return {"message": "Hello anonymous"}
    """
    if not authorization or not authorization.startswith("Bearer "):
        return None
    
    try:
        # Split and verify token exists (using maxsplit=1 to handle tokens with spaces)
        parts = authorization.split("Bearer ", 1)
        if len(parts) < 2:
            # This shouldn't happen if startswith check passed, but be defensive
            return None
        
        token = parts[1].strip()
        if not token:
            # Malformed header: "Bearer " with no token or only whitespace
            return None
        
        decoded_token = verify_firebase_token(token)
        return decoded_token
    except ValueError:
        # Expected authentication failure (invalid/expired token) - silently return None
        return None
    except Exception as e:
        # Unexpected errors (network issues, service problems, etc.) - log but still return None
        logger.warning(f"Unexpected error during optional token verification: {e}", exc_info=True)
        return None
