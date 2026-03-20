from app.config import settings
from app.schemas.workout import Interval, ParsedWorkout, WorkoutType


def test_parsed_workout_serializes_computed_timer_fields(monkeypatch):
    monkeypatch.setattr(settings, "USE_CUSTOM_PROMPT_ONLY", False)

    workout = ParsedWorkout(
        workout_type=WorkoutType.EMOM,
        intervals=[
            Interval(duration=60, type="work"),
            Interval(duration=15, type="rest"),
            Interval(duration=60, type="work"),
        ],
        raw_text="EMOM 2",
    )

    payload = workout.model_dump()

    assert "intervals" not in payload
    assert payload["duration"] == 135
    assert payload["rounds"] == 2
    assert payload["time_cap"] is None
    assert payload["timer_config"] == {
        "type": "intervals",
        "total_seconds": 135,
        "rounds": 2,
        "intervals": [
            {"duration": 60, "type": "work", "repeat": None},
            {"duration": 15, "type": "rest", "repeat": None},
            {"duration": 60, "type": "work", "repeat": None},
        ],
        "audio_cues": [],
    }


def test_parsed_workout_sets_time_cap_for_for_time_workouts(monkeypatch):
    monkeypatch.setattr(settings, "USE_CUSTOM_PROMPT_ONLY", False)

    workout = ParsedWorkout(
        workout_type=WorkoutType.FOR_TIME,
        intervals=[Interval(duration=420, type="work")],
        raw_text="For time",
    )

    assert workout.duration == 420
    assert workout.time_cap == 420
    assert workout.timer_config.type == "countdown"


def test_parsed_workout_uses_custom_prompt_only_timer_modes(monkeypatch):
    monkeypatch.setattr(settings, "USE_CUSTOM_PROMPT_ONLY", True)

    stopwatch = ParsedWorkout(
        workout_type=WorkoutType.CUSTOM,
        intervals=[Interval(duration=0, type="work")],
        raw_text="Track time",
    )
    custom = ParsedWorkout(
        workout_type=WorkoutType.CUSTOM,
        intervals=[
            Interval(duration=30, type="work"),
            Interval(duration=15, type="rest"),
        ],
        raw_text="30 on / 15 off",
    )

    assert stopwatch.timer_config.type == "stopwatch"
    assert custom.timer_config.type == "custom"
