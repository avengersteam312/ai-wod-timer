import httpx
import pytest

from app.services import supabase_auth


class DummyResponse:
    def __init__(self, status_code: int, payload: dict | None = None):
        self.status_code = status_code
        self._payload = payload or {}

    def json(self) -> dict:
        return self._payload


class DummyAsyncClient:
    def __init__(self, timeout: float, response=None, error=None, calls=None):
        self.timeout = timeout
        self._response = response
        self._error = error
        self._calls = calls if calls is not None else []

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False

    async def get(self, url: str, headers: dict):
        self._calls.append(
            {
                "url": url,
                "headers": headers,
                "timeout": self.timeout,
            }
        )
        if self._error:
            raise self._error
        return self._response


@pytest.mark.asyncio
async def test_verify_supabase_token_rejects_empty_tokens():
    with pytest.raises(ValueError, match="Token is required and must be a string"):
        await supabase_auth.verify_supabase_token("")


@pytest.mark.asyncio
async def test_verify_supabase_token_requires_supabase_url(monkeypatch):
    monkeypatch.setattr(supabase_auth.settings, "SUPABASE_URL", "")
    monkeypatch.setattr(supabase_auth.settings, "SUPABASE_ANON_KEY", "anon-key")

    with pytest.raises(ValueError, match="SUPABASE_URL is not configured"):
        await supabase_auth.verify_supabase_token("valid-token")


@pytest.mark.asyncio
async def test_verify_supabase_token_returns_user_payload(monkeypatch):
    calls: list[dict] = []
    monkeypatch.setattr(
        supabase_auth.settings, "SUPABASE_URL", "https://example.supabase.co"
    )
    monkeypatch.setattr(supabase_auth.settings, "SUPABASE_ANON_KEY", "anon-key")
    monkeypatch.setattr(
        supabase_auth.httpx,
        "AsyncClient",
        lambda timeout: DummyAsyncClient(
            timeout=timeout,
            response=DummyResponse(
                200,
                {"id": "user-123", "email": "user@example.com"},
            ),
            calls=calls,
        ),
    )

    result = await supabase_auth.verify_supabase_token("valid-token")

    assert result == {"sub": "user-123", "email": "user@example.com"}
    assert calls == [
        {
            "url": "https://example.supabase.co/auth/v1/user",
            "headers": {
                "Authorization": "Bearer valid-token",
                "apikey": "anon-key",
            },
            "timeout": 10.0,
        }
    ]


@pytest.mark.asyncio
async def test_verify_supabase_token_maps_401_to_value_error(monkeypatch):
    security_events: list[tuple[str, str, str]] = []
    monkeypatch.setattr(
        supabase_auth.settings, "SUPABASE_URL", "https://example.supabase.co"
    )
    monkeypatch.setattr(supabase_auth.settings, "SUPABASE_ANON_KEY", "anon-key")
    monkeypatch.setattr(
        supabase_auth.httpx,
        "AsyncClient",
        lambda timeout: DummyAsyncClient(timeout=timeout, response=DummyResponse(401)),
    )
    monkeypatch.setattr(
        supabase_auth,
        "log_security_event",
        lambda event, ip, detail="": security_events.append((event, ip, detail)),
    )

    with pytest.raises(ValueError, match="Invalid or expired token"):
        await supabase_auth.verify_supabase_token("expired-token")

    assert security_events == [
        ("auth.failure", "unknown", "token_rejected_by_supabase")
    ]


@pytest.mark.asyncio
async def test_verify_supabase_token_maps_non_200_status_to_value_error(monkeypatch):
    monkeypatch.setattr(
        supabase_auth.settings, "SUPABASE_URL", "https://example.supabase.co"
    )
    monkeypatch.setattr(supabase_auth.settings, "SUPABASE_ANON_KEY", "anon-key")
    monkeypatch.setattr(
        supabase_auth.httpx,
        "AsyncClient",
        lambda timeout: DummyAsyncClient(timeout=timeout, response=DummyResponse(503)),
    )

    with pytest.raises(ValueError, match="Supabase auth error: 503"):
        await supabase_auth.verify_supabase_token("valid-token")


@pytest.mark.asyncio
async def test_verify_supabase_token_maps_timeout_to_value_error(monkeypatch):
    monkeypatch.setattr(
        supabase_auth.settings, "SUPABASE_URL", "https://example.supabase.co"
    )
    monkeypatch.setattr(supabase_auth.settings, "SUPABASE_ANON_KEY", "anon-key")
    monkeypatch.setattr(
        supabase_auth.httpx,
        "AsyncClient",
        lambda timeout: DummyAsyncClient(
            timeout=timeout,
            error=httpx.TimeoutException("timed out"),
        ),
    )

    with pytest.raises(ValueError, match="Auth service timeout"):
        await supabase_auth.verify_supabase_token("valid-token")


@pytest.mark.asyncio
async def test_verify_supabase_token_maps_request_error_to_value_error(monkeypatch):
    monkeypatch.setattr(
        supabase_auth.settings, "SUPABASE_URL", "https://example.supabase.co"
    )
    monkeypatch.setattr(supabase_auth.settings, "SUPABASE_ANON_KEY", "anon-key")
    request = httpx.Request("GET", "https://example.supabase.co/auth/v1/user")
    monkeypatch.setattr(
        supabase_auth.httpx,
        "AsyncClient",
        lambda timeout: DummyAsyncClient(
            timeout=timeout,
            error=httpx.RequestError("network down", request=request),
        ),
    )

    with pytest.raises(ValueError, match="Auth service unreachable"):
        await supabase_auth.verify_supabase_token("valid-token")
