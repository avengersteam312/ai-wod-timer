import pytest

from app.observability import health


@pytest.mark.asyncio
async def test_health_returns_degraded_when_required_env_is_missing(monkeypatch):
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    monkeypatch.setattr(health.settings, "PROJECT_NAME", "AI Workout Timer")

    result = await health.health()

    assert result == {
        "status": "degraded",
        "service": "AI Workout Timer",
        "checks": {
            "openai_key": "missing",
        },
    }


@pytest.mark.asyncio
async def test_health_returns_ok_when_required_env_is_present(monkeypatch):
    monkeypatch.setenv("OPENAI_API_KEY", "sk-test")
    monkeypatch.setattr(health.settings, "PROJECT_NAME", "AI Workout Timer")

    result = await health.health()

    assert result == {
        "status": "ok",
        "service": "AI Workout Timer",
        "checks": {
            "openai_key": "ok",
        },
    }
