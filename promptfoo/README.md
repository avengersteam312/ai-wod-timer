# Promptfoo Tests for Workout Parser

This folder contains LLM prompt tests for the workout parser.

## Structure

```
promptfoo/
├── prompts/                  # Generated prompt files (don't edit manually)
│   ├── amrap.txt
│   ├── emom.txt
│   ├── for_time.txt
│   ├── tabata.txt
│   ├── intervals.txt
│   ├── stopwatch.txt
│   └── custom.txt
├── amrap.yaml                # AMRAP workout tests
├── emom.yaml                 # EMOM workout tests
├── for_time.yaml             # For Time workout tests
├── tabata.yaml               # Tabata workout tests
├── intervals.yaml            # Intervals workout tests
├── stopwatch.yaml            # Stopwatch workout tests
└── custom.yaml               # Custom workout tests
```

## Running Tests

Run all tests (recommended):
```bash
python scripts/run_tests.py
```

Run specific workout type:
```bash
python scripts/run_tests.py --type emom
```

The run_tests.py script automatically:
- Loads OPENAI_API_KEY from backend/.env
- Generates prompts from backend/app/prompts/
- Runs all test configs

## View Results

```bash
npx promptfoo view
```

## Manual Commands

If you need to run commands manually:

```bash
# Generate prompts
python scripts/generate_prompts.py

# Run single test config
export OPENAI_API_KEY="your-key"
npx promptfoo eval -c promptfoo/emom.yaml
```
