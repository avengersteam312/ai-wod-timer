"""
Workout-specific prompts for AI parsing.

Each workout type has its own detailed prompt to keep instructions focused
and reduce token usage by not sending all workout type descriptions at once.
"""

from app.prompts.prompt_manager import PromptManager, prompt_manager

__all__ = ["PromptManager", "prompt_manager"]
