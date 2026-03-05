from openai import AsyncOpenAI
from app.config import settings
from app.schemas.workout import WorkoutType
from app.prompts import prompt_manager
import json
from typing import Dict, Any, Optional


class AIService:
    def __init__(self):
        self.provider = settings.AI_PROVIDER
        self.model = settings.AI_MODEL
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)
        self.prompt_manager = prompt_manager

    async def parse_workout(
        self, workout_text: str, workout_type: Optional[WorkoutType] = None
    ) -> Dict[str, Any]:
        """
        Use AI to parse workout text and generate timer configuration.

        Args:
            workout_text: The raw workout description.
            workout_type: Pre-classified workout type (optional).
                         If provided, uses type-specific prompt for efficiency.

        Returns:
            Parsed workout data as dictionary.
        """
        # Use type-specific prompt if workout type is provided
        if workout_type:
            system_prompt = self.prompt_manager.get_system_prompt(workout_type)
        else:
            # Fallback to generic prompt for unknown types
            system_prompt = self.prompt_manager.get_system_prompt(WorkoutType.CUSTOM)

        user_prompt = self.prompt_manager.get_user_prompt(workout_text)

        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                max_tokens=2000,  # Reduced for faster responses
                response_format={"type": "json_object"},
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                temperature=0,
                timeout=8.0,  # Fail fast before Vercel 10s timeout
            )

            # Extract JSON from response
            content = response.choices[0].message.content

            # Try to parse JSON from response
            # Sometimes the model wraps it in markdown code blocks
            if "```json" in content:
                content = content.split("```json")[1].split("```")[0].strip()
            elif "```" in content:
                content = content.split("```")[1].split("```")[0].strip()

            parsed_data = json.loads(content)
            return parsed_data

        except Exception as e:
            raise Exception(f"AI parsing failed: {str(e)}")

    async def generate_audio_cues(
        self, workout_type: str, duration: int, intervals: list
    ) -> list:
        """
        Generate intelligent audio cues based on workout type and duration
        """
        cues = []

        # Start countdown
        cues.append({"time": -3, "message": "3", "type": "countdown"})
        cues.append({"time": -2, "message": "2", "type": "countdown"})
        cues.append({"time": -1, "message": "1", "type": "countdown"})
        cues.append({"time": 0, "message": "GO!", "type": "start"})

        if workout_type in ["amrap", "for_time"] and duration:
            # Time-based warnings
            if duration >= 600:  # 10+ minutes
                cues.append(
                    {
                        "time": duration // 2,
                        "message": "Halfway point",
                        "type": "announcement",
                    }
                )
            if duration >= 300:  # 5+ minutes
                cues.append(
                    {
                        "time": duration - 300,
                        "message": "5 minutes remaining",
                        "type": "warning",
                    }
                )
            if duration >= 60:
                cues.append(
                    {
                        "time": duration - 60,
                        "message": "1 minute remaining",
                        "type": "warning",
                    }
                )
            if duration >= 30:
                cues.append(
                    {"time": duration - 30, "message": "30 seconds", "type": "warning"}
                )
            if duration >= 10:
                cues.append(
                    {"time": duration - 10, "message": "10 seconds", "type": "warning"}
                )

        # Completion
        cues.append(
            {
                "time": duration if duration else 0,
                "message": "Time! Great work!",
                "type": "completion",
            }
        )

        return cues


ai_service = AIService()
