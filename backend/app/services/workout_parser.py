import re
from app.services.ai_service import ai_service
from app.services.workout_type_classifier import workout_type_classifier
from app.schemas.workout import (
    ParsedWorkout,
    WorkoutType,
    Movement,
    Interval,
)
from typing import Dict, Any, List


class WorkoutParser:
    """
    Parse workout text and generate timer configurations using AI.

    The timer is interval-based: everything is converted to a list of intervals.
    """

    def __init__(self):
        self.classifier = workout_type_classifier

    def classify_workout_type(self, workout_text: str) -> WorkoutType:
        """
        Classify workout text into a workout type using keyword matching.

        This is a fast, local classification that doesn't require AI.
        """
        return self.classifier.classify(workout_text)

    async def parse(self, workout_text: str) -> ParsedWorkout:
        """
        Main parsing method that uses AI to understand workout structure.

        1. Classify workout type locally using keywords
        2. Send type-specific prompt to AI for detailed parsing
        3. Convert AI result to intervals-based schema
        """
        # Classify workout type locally (fast, no AI)
        detected_type = self.classify_workout_type(workout_text)

        # Get AI interpretation using type-specific prompt
        ai_result = await ai_service.parse_workout(workout_text, detected_type)
        print(ai_result)
        # Ensure workout type matches our classification
        ai_result["workout_type"] = detected_type.value

        # Convert AI result to our schema
        return self._convert_ai_result(ai_result, workout_text)

    def _ends_with_rest(self, workout_text: str) -> bool:
        """
        Check if workout text explicitly ends with a rest instruction.
        """
        # Normalize text: lowercase, strip whitespace
        text = workout_text.lower().strip()
        # Check if text ends with rest pattern (e.g., "rest 1:00", "rest 1min", "rest")
        rest_pattern = r'rest\s*[\d:]*\s*(min|sec|s|m)?\s*$'
        return bool(re.search(rest_pattern, text))

    def _strip_trailing_rest(self, intervals: List[Interval], workout_text: str) -> List[Interval]:
        """
        Remove trailing rest interval if workout doesn't explicitly end with rest.
        """
        if not intervals:
            return intervals

        # If workout ends with rest instruction, keep all intervals
        if self._ends_with_rest(workout_text):
            return intervals

        # Remove trailing rest intervals (LLM sometimes adds them incorrectly)
        while intervals and intervals[-1].type == "rest":
            intervals = intervals[:-1]

        return intervals

    def _convert_ai_result(
        self, ai_result: Dict[str, Any], raw_text: str
    ) -> ParsedWorkout:
        """
        Convert AI JSON result to ParsedWorkout schema.

        The new schema is interval-based: everything is a list of intervals.
        """
        # Parse movements
        movements = [
            Movement(**movement) for movement in ai_result.get("movements", [])
        ]

        # Parse intervals directly from AI result
        intervals = [
            Interval(**interval) for interval in ai_result.get("intervals", [])
        ]

        # Strip trailing rest if workout doesn't end with rest
        intervals = self._strip_trailing_rest(intervals, raw_text)

        return ParsedWorkout(
            workout_type=WorkoutType(ai_result.get("workout_type", "custom")),
            movements=movements,
            intervals=intervals,
            raw_text=raw_text,
            ai_interpretation=ai_result.get("ai_interpretation"),
        )


workout_parser = WorkoutParser()
