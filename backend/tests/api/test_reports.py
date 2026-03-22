import time
from unittest.mock import AsyncMock, patch

import httpx
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.v1.endpoints import reports


def _build_client() -> TestClient:
    app = FastAPI()
    app.include_router(reports.router, prefix="/reports")
    return TestClient(app)


def _valid_report_payload():
    return {
        "report_kind": "wrong_workout_type",
        "message": "It was EMOM, not AMRAP",
        "original_parsed": {"type": "amrap", "rounds": 5},
        "edited_config": {"type": "emom", "rounds": 10},
        "app_version": "1.0.0+1",
        "platform": "ios",
    }


@pytest.fixture(autouse=True)
def reset_rate_limit_store():
    """Clear rate limit store before each test."""
    reports._rate_limit_store.clear()
    yield


class TestSubmitReport:
    def test_submit_report_success(self, monkeypatch):
        """Test successful report submission."""
        monkeypatch.setattr(
            reports.settings, "SUPABASE_URL", "https://test.supabase.co"
        )
        monkeypatch.setattr(reports.settings, "SUPABASE_ANON_KEY", "test-anon-key")

        mock_response = AsyncMock()
        mock_response.status_code = 201

        with patch.object(httpx.AsyncClient, "post", return_value=mock_response):
            with _build_client() as client:
                response = client.post("/reports", json=_valid_report_payload())

        assert response.status_code == 201
        data = response.json()
        assert "id" in data
        assert data["message"] == "Report submitted successfully"

    def test_submit_report_without_message(self, monkeypatch):
        """Test report submission without optional message field."""
        monkeypatch.setattr(
            reports.settings, "SUPABASE_URL", "https://test.supabase.co"
        )
        monkeypatch.setattr(reports.settings, "SUPABASE_ANON_KEY", "test-anon-key")

        mock_response = AsyncMock()
        mock_response.status_code = 201

        payload = _valid_report_payload()
        del payload["message"]

        with patch.object(httpx.AsyncClient, "post", return_value=mock_response):
            with _build_client() as client:
                response = client.post("/reports", json=payload)

        assert response.status_code == 201

    def test_submit_report_without_edited_config(self, monkeypatch):
        """Test report submission without optional edited_config field."""
        monkeypatch.setattr(
            reports.settings, "SUPABASE_URL", "https://test.supabase.co"
        )
        monkeypatch.setattr(reports.settings, "SUPABASE_ANON_KEY", "test-anon-key")

        mock_response = AsyncMock()
        mock_response.status_code = 201

        payload = _valid_report_payload()
        del payload["edited_config"]

        with patch.object(httpx.AsyncClient, "post", return_value=mock_response):
            with _build_client() as client:
                response = client.post("/reports", json=payload)

        assert response.status_code == 201

    def test_submit_report_validates_report_kind(self):
        """Test that invalid report_kind is rejected."""
        with _build_client() as client:
            payload = _valid_report_payload()
            payload["report_kind"] = "invalid_kind"
            response = client.post("/reports", json=payload)

        assert response.status_code == 422

    def test_submit_report_validates_platform(self):
        """Test that invalid platform is rejected."""
        with _build_client() as client:
            payload = _valid_report_payload()
            payload["platform"] = "windows"
            response = client.post("/reports", json=payload)

        assert response.status_code == 422

    def test_submit_report_requires_original_parsed(self):
        """Test that original_parsed is required."""
        with _build_client() as client:
            payload = _valid_report_payload()
            del payload["original_parsed"]
            response = client.post("/reports", json=payload)

        assert response.status_code == 422

    def test_submit_report_requires_app_version(self):
        """Test that app_version is required."""
        with _build_client() as client:
            payload = _valid_report_payload()
            del payload["app_version"]
            response = client.post("/reports", json=payload)

        assert response.status_code == 422

    def test_submit_report_rate_limit_exceeded(self, monkeypatch):
        """Test rate limiting after 10 reports from same IP."""
        monkeypatch.setattr(
            reports.settings, "SUPABASE_URL", "https://test.supabase.co"
        )
        monkeypatch.setattr(reports.settings, "SUPABASE_ANON_KEY", "test-anon-key")

        mock_response = AsyncMock()
        mock_response.status_code = 201

        with patch.object(httpx.AsyncClient, "post", return_value=mock_response):
            with _build_client() as client:
                # Submit 10 reports (should all succeed)
                for _ in range(10):
                    response = client.post("/reports", json=_valid_report_payload())
                    assert response.status_code == 201

                # 11th report should be rate limited
                response = client.post("/reports", json=_valid_report_payload())
                assert response.status_code == 429
                assert "Too many reports" in response.json()["detail"]

    def test_submit_report_supabase_not_configured(self, monkeypatch):
        """Test error when Supabase is not configured."""
        monkeypatch.setattr(reports.settings, "SUPABASE_URL", "")
        monkeypatch.setattr(reports.settings, "SUPABASE_ANON_KEY", "")

        with _build_client() as client:
            response = client.post("/reports", json=_valid_report_payload())

        assert response.status_code == 503
        assert "not configured" in response.json()["detail"]

    def test_submit_report_supabase_insert_fails(self, monkeypatch):
        """Test error handling when Supabase insert fails."""
        monkeypatch.setattr(
            reports.settings, "SUPABASE_URL", "https://test.supabase.co"
        )
        monkeypatch.setattr(reports.settings, "SUPABASE_ANON_KEY", "test-anon-key")

        mock_response = AsyncMock()
        mock_response.status_code = 500
        mock_response.text = "Internal Server Error"

        with patch.object(httpx.AsyncClient, "post", return_value=mock_response):
            with _build_client() as client:
                response = client.post("/reports", json=_valid_report_payload())

        assert response.status_code == 500
        assert "Failed to save report" in response.json()["detail"]

    def test_submit_report_supabase_timeout(self, monkeypatch):
        """Test error handling when Supabase times out."""
        monkeypatch.setattr(
            reports.settings, "SUPABASE_URL", "https://test.supabase.co"
        )
        monkeypatch.setattr(reports.settings, "SUPABASE_ANON_KEY", "test-anon-key")

        async def timeout_side_effect(*args, **kwargs):
            raise httpx.TimeoutException("Connection timed out")

        with patch.object(httpx.AsyncClient, "post", side_effect=timeout_side_effect):
            with _build_client() as client:
                response = client.post("/reports", json=_valid_report_payload())

        assert response.status_code == 504
        assert "timeout" in response.json()["detail"].lower()


class TestRateLimiter:
    def test_rate_limit_window_expires(self, monkeypatch):
        """Test that rate limit resets after window expires."""
        monkeypatch.setattr(
            reports.settings, "SUPABASE_URL", "https://test.supabase.co"
        )
        monkeypatch.setattr(reports.settings, "SUPABASE_ANON_KEY", "test-anon-key")
        monkeypatch.setattr(reports, "_RATE_LIMIT_WINDOW", 1)  # 1 second window

        mock_response = AsyncMock()
        mock_response.status_code = 201

        with patch.object(httpx.AsyncClient, "post", return_value=mock_response):
            with _build_client() as client:
                # Submit 10 reports
                for _ in range(10):
                    response = client.post("/reports", json=_valid_report_payload())
                    assert response.status_code == 201

                # 11th should fail
                response = client.post("/reports", json=_valid_report_payload())
                assert response.status_code == 429

                # Wait for window to expire
                time.sleep(1.1)

                # Should work again
                response = client.post("/reports", json=_valid_report_payload())
                assert response.status_code == 201

    def test_different_ips_have_separate_limits(self, monkeypatch):
        """Test that rate limits are per-IP."""
        monkeypatch.setattr(
            reports.settings, "SUPABASE_URL", "https://test.supabase.co"
        )
        monkeypatch.setattr(reports.settings, "SUPABASE_ANON_KEY", "test-anon-key")

        mock_response = AsyncMock()
        mock_response.status_code = 201

        with patch.object(httpx.AsyncClient, "post", return_value=mock_response):
            with _build_client() as client:
                # Exhaust limit for IP 1.1.1.1
                for _ in range(10):
                    response = client.post(
                        "/reports",
                        json=_valid_report_payload(),
                        headers={"X-Forwarded-For": "1.1.1.1"},
                    )
                    assert response.status_code == 201

                # IP 1.1.1.1 should be rate limited
                response = client.post(
                    "/reports",
                    json=_valid_report_payload(),
                    headers={"X-Forwarded-For": "1.1.1.1"},
                )
                assert response.status_code == 429

                # IP 2.2.2.2 should still work
                response = client.post(
                    "/reports",
                    json=_valid_report_payload(),
                    headers={"X-Forwarded-For": "2.2.2.2"},
                )
                assert response.status_code == 201
