"""
Prompt manager for selecting workout-specific prompts.

This module provides a centralized way to get the appropriate prompt
based on the detected workout type, reducing token usage by only
sending relevant instructions to the LLM.
"""

from app.schemas.workout import WorkoutType
from app.prompts.base import BASE_SYSTEM_PROMPT, USER_PROMPT_TEMPLATE
from app.prompts.amrap import AMRAP_PROMPT
from app.prompts.emom import EMOM_PROMPT
from app.prompts.for_time import FOR_TIME_PROMPT
from app.prompts.tabata import TABATA_PROMPT
from app.prompts.intervals import INTERVALS_PROMPT
from app.prompts.stopwatch import STOPWATCH_PROMPT
from app.prompts.custom import CUSTOM_PROMPT


class PromptManager:
    """
    Manages workout-specific prompts for AI parsing.

    Usage:
        manager = PromptManager()
        system_prompt = manager.get_system_prompt(WorkoutType.AMRAP)
        user_prompt = manager.get_user_prompt("AMRAP 20: 10 burpees...")
    """

    def __init__(self):
        self._prompts: dict[WorkoutType, str] = {
            WorkoutType.AMRAP: AMRAP_PROMPT,
            WorkoutType.EMOM: EMOM_PROMPT,
            WorkoutType.FOR_TIME: FOR_TIME_PROMPT,
            WorkoutType.TABATA: TABATA_PROMPT,
            WorkoutType.INTERVALS: INTERVALS_PROMPT,
            WorkoutType.STOPWATCH: STOPWATCH_PROMPT,
            WorkoutType.CUSTOM: CUSTOM_PROMPT,
        }

    def get_workout_prompt(self, workout_type: WorkoutType) -> str:
        """
        Get the workout-specific prompt for a given type.

        Args:
            workout_type: The classified workout type.

        Returns:
            The workout-specific prompt string.
        """
        return self._prompts.get(workout_type, CUSTOM_PROMPT)

    def get_system_prompt(self, workout_type: WorkoutType) -> str:
        """
        Get the complete system prompt for a workout type.

        Combines the workout-specific instructions with the base template
        that defines the JSON output structure.

        Args:
            workout_type: The classified workout type.

        Returns:
            Complete system prompt ready for LLM.
        """
        workout_prompt = self.get_workout_prompt(workout_type)
        base_prompt = BASE_SYSTEM_PROMPT.format(workout_type=workout_type.value)

        return f"{workout_prompt}\n\n{base_prompt}"

    def get_user_prompt(self, workout_text: str) -> str:
        """
        Get the user prompt with the workout text.

        Args:
            workout_text: The raw workout description.

        Returns:
            Formatted user prompt.
        """
        return USER_PROMPT_TEMPLATE.format(workout_text=workout_text)

    def set_prompt(self, workout_type: WorkoutType, prompt: str) -> None:
        """
        Set or override the prompt for a workout type.

        Args:
            workout_type: The workout type to configure.
            prompt: The new prompt text.
        """
        self._prompts[workout_type] = prompt

    def get_all_prompts(self) -> dict[WorkoutType, str]:
        """Get all workout prompts."""
        return self._prompts.copy()


# Singleton instance
prompt_manager = PromptManager()
