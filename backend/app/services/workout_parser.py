from app.services.ai_service import ai_service
from app.schemas.workout import (
    ParsedWorkout,
    WorkoutType,
    Movement,
    TimerConfig,
    AudioCue,
    Interval,
)
from typing import Dict, Any


class WorkoutParser:
    """
    Parse workout text and generate timer configurations using AI
    """

    async def parse(self, workout_text: str) -> ParsedWorkout:
        """
        Main parsing method that uses AI to understand workout structure
        """
        # Get AI interpretation
        ai_result = await ai_service.parse_workout(workout_text)

        # Convert AI result to our schema
        parsed_workout = self._convert_ai_result(ai_result, workout_text)

        return parsed_workout

    def _convert_ai_result(
        self, ai_result: Dict[str, Any], raw_text: str
    ) -> ParsedWorkout:
        """
        Convert AI JSON result to ParsedWorkout schema
        """
        # Parse movements
        movements = [
            Movement(**movement) for movement in ai_result.get("movements", [])
        ]

        # Parse timer config
        timer_data = ai_result.get("timer_config", {})
        intervals = [
            Interval(**interval) for interval in timer_data.get("intervals", [])
        ]
        audio_cues = [AudioCue(**cue) for cue in timer_data.get("audio_cues", [])]

        timer_config = TimerConfig(
            type=timer_data.get("type", "countdown"),
            total_seconds=timer_data.get("total_seconds"),
            rounds=timer_data.get("rounds"),
            intervals=intervals,
            audio_cues=audio_cues,
            rest_between_rounds=timer_data.get("rest_between_rounds"),
        )

        # Create ParsedWorkout
        return ParsedWorkout(
            workout_type=WorkoutType(ai_result.get("workout_type", "custom")),
            movements=movements,
            rounds=ai_result.get("rounds"),
            duration=ai_result.get("duration"),
            time_cap=ai_result.get("time_cap"),
            rest_between_rounds=ai_result.get("rest_between_rounds"),
            timer_config=timer_config,
            raw_text=raw_text,
            ai_interpretation=ai_result.get("ai_interpretation"),
        )


workout_parser = WorkoutParser()
