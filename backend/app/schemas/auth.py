"""
Authentication response schemas.
"""
from pydantic import BaseModel
from typing import Optional


class UserInfoResponse(BaseModel):
    """User information response model."""
    uid: str
    email: Optional[str] = None
    email_verified: bool = False
    auth_time: Optional[int] = None

    class Config:
        json_schema_extra = {
            "example": {
                "uid": "supabase-user-id",
                "email": "user@example.com",
                "email_verified": True,
                "auth_time": 1234567890,
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
                "user_id": "supabase-user-id",
                "email": "user@example.com"
            }
        }
