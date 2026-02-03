"""
Authentication endpoints for Supabase authentication.
"""
from fastapi import APIRouter, Depends
from app.api.v1.dependencies import get_current_user
from app.schemas.auth import UserInfoResponse, TestProtectedResponse
from typing import Dict, Any

router = APIRouter()


@router.get("/me", response_model=UserInfoResponse)
async def get_current_user_info(
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> UserInfoResponse:
    """
    Get current authenticated user information.

    This is a protected endpoint that requires a valid Supabase access token.

    Usage:
    - Include Authorization header: `Bearer <supabase_access_token>`

    Returns:
        UserInfoResponse: User information including ID and email
    """
    return UserInfoResponse(
        uid=current_user.get("sub", ""),
        email=current_user.get("email"),
        email_verified=current_user.get("email_confirmed_at") is not None,
        auth_time=current_user.get("iat"),
    )


@router.get("/test-protected", response_model=TestProtectedResponse)
async def test_protected_route(
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> TestProtectedResponse:
    """
    Simple test endpoint to verify authentication is working.
    """
    return TestProtectedResponse(
        message="Authentication successful!",
        user_id=current_user.get("sub", ""),
        email=current_user.get("email", "unknown")
    )
