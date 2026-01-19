"""
Authentication endpoints for testing Firebase authentication.
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
    
    This is a protected endpoint that requires a valid Firebase token.
    Returns the decoded Firebase token with user information.
    
    Usage:
    - Include Authorization header: `Bearer <firebase_id_token>`
    - Token is automatically verified by the backend
    
    Returns:
        UserInfoResponse: User information including UID, email, and auth metadata
    """
    firebase_info = current_user.get("firebase", {})
    return UserInfoResponse(
        uid=current_user.get("uid", ""),
        email=current_user.get("email"),
        email_verified=current_user.get("email_verified", False),
        auth_time=current_user.get("auth_time"),
        firebase={
            "sign_in_provider": firebase_info.get("sign_in_provider") if firebase_info else None,
        }
    )


@router.get("/test-protected", response_model=TestProtectedResponse)
async def test_protected_route(
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> TestProtectedResponse:
    """
    Simple test endpoint to verify authentication is working.
    
    Returns a success message if the token is valid.
    
    Returns:
        TestProtectedResponse: Success message with user identification
    """
    return TestProtectedResponse(
        message="Authentication successful!",
        user_id=current_user.get("uid", ""),
        email=current_user.get("email", "unknown")
    )
