#!/usr/bin/env python3
"""
Run all promptfoo tests.

This script:
1. Loads OPENAI_API_KEY from backend/.env
2. Generates prompts from backend/app/prompts/
3. Runs all promptfoo tests

Usage:
    python scripts/run_tests.py
    python scripts/run_tests.py --type emom  # Run single type
"""

import os
import subprocess
import sys
from pathlib import Path

# Get project root (1 level up from this script)
PROJECT_ROOT = Path(__file__).parent.parent


def load_env():
    """Load OPENAI_API_KEY from backend/.env"""
    env_file = PROJECT_ROOT / "backend" / ".env"
    if not env_file.exists():
        print(f"Error: {env_file} not found")
        sys.exit(1)

    with open(env_file) as f:
        for line in f:
            line = line.strip()
            if line.startswith("OPENAI_API_KEY"):
                # Handle: OPENAI_API_KEY=value or OPENAI_API_KEY="value"
                _, _, value = line.partition("=")
                value = value.strip().strip("'\"")
                os.environ["OPENAI_API_KEY"] = value
                print("Loaded OPENAI_API_KEY from backend/.env")
                return

    print("Error: OPENAI_API_KEY not found in backend/.env")
    sys.exit(1)


def generate_prompts():
    """Generate prompts from backend."""
    print("\n=== Generating prompts ===")
    script = PROJECT_ROOT / "scripts" / "generate_prompts.py"
    result = subprocess.run([sys.executable, str(script)], cwd=PROJECT_ROOT)
    if result.returncode != 0:
        print("Error generating prompts")
        sys.exit(1)


def run_tests(workout_type: str = None):
    """Run promptfoo tests."""
    promptfoo_dir = PROJECT_ROOT / "promptfoo"

    if workout_type:
        configs = [promptfoo_dir / f"{workout_type}.yaml"]
        if not configs[0].exists():
            print(f"Error: {configs[0]} not found")
            sys.exit(1)
    else:
        configs = sorted(promptfoo_dir.glob("*.yaml"))

    if not configs:
        print("No test configs found")
        sys.exit(1)

    print(f"\n=== Running {len(configs)} test config(s) ===\n")

    failed = []
    for config in configs:
        print(f"\n--- Testing: {config.name} ---")
        result = subprocess.run(
            ["npx", "promptfoo", "eval", "-c", str(config), "--no-cache"],
            cwd=PROJECT_ROOT,
        )
        if result.returncode != 0:
            failed.append(config.name)

    print("\n" + "=" * 50)
    if failed:
        print(f"FAILED: {', '.join(failed)}")
        sys.exit(1)
    else:
        print(f"All {len(configs)} test configs passed!")


def main():
    workout_type = None
    if len(sys.argv) > 1:
        if sys.argv[1] == "--type" and len(sys.argv) > 2:
            workout_type = sys.argv[2]
        else:
            print("Usage: python run_tests.py [--type workout_type]")
            sys.exit(1)

    load_env()
    generate_prompts()
    run_tests(workout_type)


if __name__ == "__main__":
    main()
