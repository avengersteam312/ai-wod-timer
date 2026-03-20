import pytest
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials

from app.api.v1 import dependencies


@pytest.mark.asyncio
async def test_get_current_user_returns_decoded_token(monkeypatch):
    async def fake_verify(token: str) -> dict:
        assert token == "valid-token"
        return {"sub": "user-123", "email": "user@example.com"}

    monkeypatch.setattr(dependencies, "verify_supabase_token", fake_verify)

    credentials = HTTPAuthorizationCredentials(
        scheme="Bearer",
        credentials="valid-token",
    )

    result = await dependencies.get_current_user(credentials)

    assert result == {"sub": "user-123", "email": "user@example.com"}


@pytest.mark.asyncio
async def test_get_current_user_maps_value_error_to_401(monkeypatch):
    async def fake_verify(token: str) -> dict:
        raise ValueError("expired")

    monkeypatch.setattr(dependencies, "verify_supabase_token", fake_verify)

    credentials = HTTPAuthorizationCredentials(
        scheme="Bearer",
        credentials="expired-token",
    )

    with pytest.raises(HTTPException) as exc_info:
        await dependencies.get_current_user(credentials)

    assert exc_info.value.status_code == 401
    assert exc_info.value.detail == "Invalid or expired authentication token"
    assert exc_info.value.headers == {"WWW-Authenticate": "Bearer"}


@pytest.mark.asyncio
async def test_get_current_user_maps_unexpected_error_to_500(monkeypatch):
    async def fake_verify(token: str) -> dict:
        raise RuntimeError("boom")

    monkeypatch.setattr(dependencies, "verify_supabase_token", fake_verify)

    credentials = HTTPAuthorizationCredentials(
        scheme="Bearer",
        credentials="bad-token",
    )

    with pytest.raises(HTTPException) as exc_info:
        await dependencies.get_current_user(credentials)

    assert exc_info.value.status_code == 500
    assert exc_info.value.detail == "Authentication service error"


@pytest.mark.asyncio
async def test_get_current_user_optional_returns_none_without_bearer_header():
    assert await dependencies.get_current_user_optional(None) is None
    assert await dependencies.get_current_user_optional("Basic abc123") is None
    assert await dependencies.get_current_user_optional("Bearer   ") is None


@pytest.mark.asyncio
async def test_get_current_user_optional_returns_user_when_token_is_valid(monkeypatch):
    async def fake_verify(token: str) -> dict:
        assert token == "valid-token"
        return {"sub": "user-123"}

    monkeypatch.setattr(dependencies, "verify_supabase_token", fake_verify)

    result = await dependencies.get_current_user_optional("Bearer valid-token")

    assert result == {"sub": "user-123"}


@pytest.mark.asyncio
async def test_get_current_user_optional_swallows_verification_failures(monkeypatch):
    async def raises_value_error(token: str) -> dict:
        raise ValueError("expired")

    monkeypatch.setattr(dependencies, "verify_supabase_token", raises_value_error)
    assert await dependencies.get_current_user_optional("Bearer expired-token") is None

    async def raises_runtime_error(token: str) -> dict:
        raise RuntimeError("supabase down")

    monkeypatch.setattr(dependencies, "verify_supabase_token", raises_runtime_error)
    assert await dependencies.get_current_user_optional("Bearer valid-token") is None
