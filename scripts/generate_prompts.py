#!/usr/bin/env python3
"""
Generate prompt files for promptfoo testing.

This script reads the prompts from backend/app/prompts/ and generates
text files that promptfoo can use, ensuring tests use the actual prompts.

Usage:
    python scripts/generate_prompts.py
"""

import sys
from pathlib import Path

# Add backend to path so we can import the prompts
backend_path = Path(__file__).parent.parent / "backend"
sys.path.insert(0, str(backend_path))

from app.prompts.base import BASE_SYSTEM_PROMPT, USER_PROMPT_TEMPLATE
from app.prompts.amrap import AMRAP_PROMPT
from app.prompts.emom import EMOM_PROMPT
from app.prompts.for_time import FOR_TIME_PROMPT
from app.prompts.tabata import TABATA_PROMPT
from app.prompts.intervals import INTERVALS_PROMPT
from app.prompts.stopwatch import STOPWATCH_PROMPT
from app.prompts.custom import CUSTOM_PROMPT


def generate_prompt(workout_type: str, workout_prompt: str) -> str:
    """Generate complete prompt for a workout type.

    Converts Python f-string placeholders {var} to Handlebars {{var}} for promptfoo.
    """
    base = BASE_SYSTEM_PROMPT.format(workout_type=workout_type)
    prompt = f"{workout_prompt}\n\n{base}\n\n{USER_PROMPT_TEMPLATE}"
    # Convert {workout_text} to {{workout_text}} for promptfoo (Handlebars syntax)
    prompt = prompt.replace("{workout_text}", "{{workout_text}}")
    return prompt


def main():
    prompts_dir = Path(__file__).parent.parent / "promptfoo" / "prompts"
    prompts_dir.mkdir(exist_ok=True)

    prompts = {
        "amrap": AMRAP_PROMPT,
        "emom": EMOM_PROMPT,
        "for_time": FOR_TIME_PROMPT,
        "tabata": TABATA_PROMPT,
        "intervals": INTERVALS_PROMPT,
        "stopwatch": STOPWATCH_PROMPT,
        "custom": CUSTOM_PROMPT,
    }

    for workout_type, workout_prompt in prompts.items():
        prompt = generate_prompt(workout_type, workout_prompt)
        output_file = prompts_dir / f"{workout_type}.txt"
        output_file.write_text(prompt)
        print(f"Generated: {output_file}")

    print(f"\nAll prompts generated in {prompts_dir}")


if __name__ == "__main__":
    main()
