"""
Authentication response schemas.
"""
from pydantic import BaseModel
from typing import Optional


class FirebaseInfo(BaseModel):
    """Firebase authentication provider information."""
    sign_in_provider: Optional[str] = None


class UserInfoResponse(BaseModel):
    """User information response model."""
    uid: str
    email: Optional[str] = None
    email_verified: bool = False
    auth_time: Optional[int] = None
    firebase: FirebaseInfo

    class Config:
        json_schema_extra = {
            "example": {
                "uid": "firebase-user-id",
                "email": "user@example.com",
                "email_verified": False,
                "auth_time": 1234567890,
                "firebase": {
                    "sign_in_provider": "password"
                }
            }
        }


class TestProtectedResponse(BaseModel):
    """Test protected endpoint response."""
    message: str
    user_id: str
    email: str

    class Config:
        json_schema_extra = {
            "example": {
                "message": "Authentication successful!",
                "user_id": "firebase-user-id",
                "email": "user@example.com"
            }
        }
