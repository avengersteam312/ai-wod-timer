#!/usr/bin/env python3
"""
Generate prompt files for promptfoo testing.

This script reads the prompts from backend/app/prompts/ and generates
text files that promptfoo can use, ensuring tests use the actual prompts.

Usage:
    python scripts/generate_prompts.py
"""

import importlib
import sys
from pathlib import Path


def load_prompts() -> tuple[str, str, dict[str, str]]:
    """Load backend prompt modules after adding backend to sys.path."""
    backend_path = Path(__file__).parent.parent / "backend"
    backend_path_str = str(backend_path)
    if backend_path_str not in sys.path:
        sys.path.insert(0, backend_path_str)

    base_module = importlib.import_module("app.prompts.base")
    prompt_modules = {
        "amrap": importlib.import_module("app.prompts.amrap").AMRAP_PROMPT,
        "emom": importlib.import_module("app.prompts.emom").EMOM_PROMPT,
        "for_time": importlib.import_module("app.prompts.for_time").FOR_TIME_PROMPT,
        "tabata": importlib.import_module("app.prompts.tabata").TABATA_PROMPT,
        "intervals": importlib.import_module("app.prompts.intervals").INTERVALS_PROMPT,
        "stopwatch": importlib.import_module("app.prompts.stopwatch").STOPWATCH_PROMPT,
        "custom": importlib.import_module("app.prompts.custom").CUSTOM_PROMPT,
    }
    return (
        base_module.BASE_SYSTEM_PROMPT,
        base_module.USER_PROMPT_TEMPLATE,
        prompt_modules,
    )


def generate_prompt(
    workout_type: str,
    workout_prompt: str,
    base_system_prompt: str,
    user_prompt_template: str,
) -> str:
    """Generate complete prompt for a workout type.

    Converts Python f-string placeholders {var} to Handlebars {{var}} for promptfoo.
    """
    base = base_system_prompt.format(workout_type=workout_type)
    prompt = f"{workout_prompt}\n\n{base}\n\n{user_prompt_template}"
    # Convert {workout_text} to {{workout_text}} for promptfoo (Handlebars syntax)
    prompt = prompt.replace("{workout_text}", "{{workout_text}}")
    return prompt


def main():
    prompts_dir = Path(__file__).parent.parent / "promptfoo" / "prompts"
    prompts_dir.mkdir(exist_ok=True)

    base_system_prompt, user_prompt_template, prompts = load_prompts()

    for workout_type, workout_prompt in prompts.items():
        prompt = generate_prompt(
            workout_type,
            workout_prompt,
            base_system_prompt,
            user_prompt_template,
        )
        output_file = prompts_dir / f"{workout_type}.txt"
        output_file.write_text(prompt)
        print(f"Generated: {output_file}")

    print(f"\nAll prompts generated in {prompts_dir}")


if __name__ == "__main__":
    main()
