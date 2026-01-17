from openai import OpenAI
from app.config import settings
import json
from typing import Dict, Any


class AIService:
    def __init__(self):
        self.provider = settings.AI_PROVIDER
        self.model = settings.AI_MODEL
        self.client = OpenAI(api_key=settings.OPENAI_API_KEY)

    async def parse_workout(self, workout_text: str) -> Dict[str, Any]:
        """
        Use AI to parse workout text and generate timer configuration
        """
        system_prompt = """You are a CrossFit and functional fitness timer configuration assistant.
Parse workout descriptions and generate precise timer configurations.

Identify workout types:
- AMRAP: As Many Rounds As Possible in X minutes
- EMOM: Every Minute On the Minute for X minutes
- For Time: Complete work as fast as possible (may have time cap)
- Tabata: 20 seconds work / 10 seconds rest intervals
- Rounds: X rounds of movements (may be for time or with rest)
- Chipper: Long list of movements done once for time

Return a JSON object with this exact structure:
{
  "workout_type": "amrap|emom|for_time|tabata|rounds|custom",
  "movements": [{"name": "Movement Name", "reps": 10, "weight": "20/14 lbs", "duration": null}],
  "rounds": null or number,
  "duration": total_seconds or null,
  "time_cap": seconds or null,
  "rest_between_rounds": seconds or null,
  "timer_config": {
    "type": "countdown|intervals|rounds|tabata",
    "total_seconds": number or null,
    "rounds": number or null,
    "intervals": [{"duration": seconds, "label": "Work/Rest", "type": "work|rest"}],
    "audio_cues": [{"time": seconds_from_start, "message": "text", "type": "announcement"}],
    "rest_between_rounds": seconds or null
  },
  "ai_interpretation": "Brief explanation of the workout structure"
}

Audio cues guidelines:
- Add countdown at start (3, 2, 1, GO)
- Add warnings at key intervals (halfway, 5min, 1min, 30sec, 10sec remaining)
- For EMOM, announce each minute
- For Tabata, announce work/rest transitions
- Add completion message

Be precise with time calculations and ensure audio cues align with workout structure."""

        user_prompt = f"""Parse this workout and generate a timer configuration:

{workout_text}

Return only the JSON object, no other text."""

        try:
            response = self.client.chat.completions.create(
                model=self.model,
                max_tokens=2000,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
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
