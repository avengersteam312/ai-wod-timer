from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.v1.endpoints import timer
from app.schemas.workout import Interval, Movement, ParsedWorkout, WorkoutType


class StubParser:
    def __init__(self, result=None, error=None):
        self.result = result
        self.error = error
        self.calls: list[str] = []

    async def parse(self, workout_text: str):
        self.calls.append(workout_text)
        if self.error:
            raise self.error
        return self.result


def _build_client() -> TestClient:
    app = FastAPI()
    app.include_router(timer.router)
    return TestClient(app)


def test_parse_workout_returns_parsed_payload(monkeypatch):
    parser = StubParser(
        result=ParsedWorkout(
            workout_type=WorkoutType.AMRAP,
            movements=[Movement(name="Burpees", reps=10)],
            intervals=[Interval(duration=1_200, type="work")],
            raw_text="AMRAP 20",
            ai_interpretation="Classic conditioning",
        )
    )
    requested_modes: list[bool | None] = []

    def fake_get_parser(use_agent=None):
        requested_modes.append(use_agent)
        return parser

    monkeypatch.setattr(timer, "_get_parser", fake_get_parser)

    with _build_client() as client:
        response = client.post(
            "/parse",
            params={"use_agent": "true"},
            json={"workout_text": "AMRAP 20"},
        )

    assert response.status_code == 200
    assert requested_modes == [True]
    assert parser.calls == ["AMRAP 20"]
    assert response.json()["workout_type"] == "amrap"
    assert response.json()["duration"] == 1_200
    assert response.json()["timer_config"]["type"] == "intervals"


def test_parse_workout_returns_400_for_validation_errors(monkeypatch):
    parser = StubParser(error=ValueError("missing rounds"))
    monkeypatch.setattr(timer, "_get_parser", lambda use_agent=None: parser)

    with _build_client() as client:
        response = client.post("/parse", json={"workout_text": "broken"})

    assert response.status_code == 400
    assert response.json() == {"detail": "Invalid workout format: missing rounds"}


def test_parse_workout_returns_500_for_unexpected_errors(monkeypatch):
    parser = StubParser(error=RuntimeError("model failed"))
    monkeypatch.setattr(timer, "_get_parser", lambda use_agent=None: parser)

    with _build_client() as client:
        response = client.post("/parse", json={"workout_text": "broken"})

    assert response.status_code == 500
    assert response.json() == {
        "detail": "Failed to parse workout. Please check the format and try again."
    }


def test_parse_workout_from_image_rejects_invalid_content_type():
    with _build_client() as client:
        response = client.post(
            "/parse-image",
            files={"file": ("notes.txt", b"not an image", "text/plain")},
        )

    assert response.status_code == 400
    assert "Invalid file type" in response.json()["detail"]


def test_parse_workout_from_image_rejects_oversized_files():
    oversized = b"x" * ((5 * 1024 * 1024) + 1)

    with _build_client() as client:
        response = client.post(
            "/parse-image",
            files={"file": ("large.png", oversized, "image/png")},
        )

    assert response.status_code == 400
    assert response.json() == {"detail": "File too large. Maximum size is 5MB."}


def test_parse_workout_from_image_returns_400_when_no_text_is_found(monkeypatch):
    async def fake_extract_text(content: bytes, content_type: str):
        return "   ", "Workout"

    monkeypatch.setattr(timer.ai_service, "extract_text_from_image", fake_extract_text)
    monkeypatch.setattr(timer, "_get_parser", lambda use_agent=None: StubParser())

    with _build_client() as client:
        response = client.post(
            "/parse-image",
            files={"file": ("workout.png", b"image-bytes", "image/png")},
        )

    assert response.status_code == 400
    assert response.json() == {"detail": "No workout text found in image"}


def test_parse_workout_from_image_overrides_raw_text_and_name(monkeypatch):
    parser = StubParser(
        result=ParsedWorkout(
            workout_type=WorkoutType.FOR_TIME,
            movements=[Movement(name="Thrusters", reps=21)],
            intervals=[Interval(duration=600, type="work")],
            raw_text="placeholder",
            ai_interpretation=None,
        )
    )

    async def fake_extract_text(content: bytes, content_type: str):
        assert content == b"image-bytes"
        assert content_type == "image/png"
        return "For time\n21-15-9 Thrusters", "Fran"

    monkeypatch.setattr(timer.ai_service, "extract_text_from_image", fake_extract_text)
    monkeypatch.setattr(timer, "_get_parser", lambda use_agent=None: parser)

    with _build_client() as client:
        response = client.post(
            "/parse-image",
            files={"file": ("workout.png", b"image-bytes", "image/png")},
        )

    assert response.status_code == 200
    payload = response.json()
    assert parser.calls == ["For time\n21-15-9 Thrusters"]
    assert payload["raw_text"] == "For time\n21-15-9 Thrusters"
    assert payload["ai_interpretation"] == "Fran"


def test_parse_workout_from_image_returns_500_for_parser_failures(monkeypatch):
    parser = StubParser(error=RuntimeError("parse failed"))

    async def fake_extract_text(content: bytes, content_type: str):
        return "EMOM 10", "Workout"

    monkeypatch.setattr(timer.ai_service, "extract_text_from_image", fake_extract_text)
    monkeypatch.setattr(timer, "_get_parser", lambda use_agent=None: parser)

    with _build_client() as client:
        response = client.post(
            "/parse-image",
            files={"file": ("workout.png", b"image-bytes", "image/png")},
        )

    assert response.status_code == 500
    assert response.json() == {
        "detail": "Failed to parse workout from image. Please try again with a clearer image."
    }
