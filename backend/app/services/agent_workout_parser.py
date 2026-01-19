"""
Agent-based workout parser using OpenAI Agents SDK.

This module provides the same interface as workout_parser.py but uses
the agent workflow internally for parsing.
"""

import re
from typing import List

from app.services.agent_workflow import agent_workflow
from app.schemas.workout import (
    ParsedWorkout,
    WorkoutType,
    Movement,
    Interval,
)


class AgentWorkoutParser:
    """
    Parse workout text using AI agents.

    This parser uses the OpenAI Agents SDK for a two-stage workflow:
    1. Fast classification using a lightweight model
    2. Type-specific parsing with appropriate prompts
    """

    async def parse(self, workout_text: str) -> ParsedWorkout:
        """
        Parse workout text using the agent workflow.

        Args:
            workout_text: Raw workout description

        Returns:
            ParsedWorkout object with structured data
        """
        # Run the agent workflow
        ai_result = await agent_workflow.parse(workout_text)

        # Convert to our schema
        return self._convert_ai_result(ai_result, workout_text)

    def _ends_with_rest(self, workout_text: str) -> bool:
        """Check if workout text explicitly ends with a rest instruction."""
        text = workout_text.lower().strip()
        rest_pattern = r"rest\s*[\d:]*\s*(min|sec|s|m)?\s*$"
        return bool(re.search(rest_pattern, text))

    def _strip_trailing_rest(
        self, intervals: List[Interval], workout_text: str
    ) -> List[Interval]:
        """Remove trailing rest interval if workout doesn't explicitly end with rest."""
        if not intervals:
            return intervals

        if self._ends_with_rest(workout_text):
            return intervals

        while intervals and intervals[-1].type == "rest":
            intervals = intervals[:-1]

        return intervals

    def _convert_ai_result(self, ai_result: dict, raw_text: str) -> ParsedWorkout:
        """Convert agent workflow result to ParsedWorkout schema."""
        # Parse movements
        movements = []
        for m in ai_result.get("movements", []):
            # Handle both float and int reps
            reps = m.get("reps")
            if reps is not None:
                reps = int(reps) if float(reps).is_integer() else reps

            movement_data = {
                "name": m.get("name", ""),
                "reps": reps,
                "duration": m.get("duration"),
                "weight": m.get("weight"),
                "notes": m.get("notes"),
            }
            # Filter out None values for cleaner objects
            movement_data = {k: v for k, v in movement_data.items() if v is not None}
            movements.append(Movement(**movement_data))

        # Parse intervals
        intervals = []
        for i in ai_result.get("intervals", []):
            duration = i.get("duration", 0)
            # Convert float to int for duration
            duration = int(duration) if isinstance(duration, float) else duration
            intervals.append(Interval(
                duration=duration,
                type=i.get("type", "work")
            ))

        # Strip trailing rest if needed
        intervals = self._strip_trailing_rest(intervals, raw_text)

        # Get workout type
        workout_type_str = ai_result.get("workout_type", "custom")
        try:
            workout_type = WorkoutType(workout_type_str)
        except ValueError:
            workout_type = WorkoutType.CUSTOM

        return ParsedWorkout(
            workout_type=workout_type,
            movements=movements,
            intervals=intervals,
            raw_text=raw_text,
            ai_interpretation=ai_result.get("ai_interpretation"),
        )


# Singleton instance
agent_workout_parser = AgentWorkoutParser()
