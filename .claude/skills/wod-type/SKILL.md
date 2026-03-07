---
name: wod-type
description: "Checklist for adding a new workout type to ai-wod-timer. Use when adding a workout type, new timer type, or supporting a new workout format. Triggers on: add workout type, new timer type, support new workout format."
# consumers:
#   - standalone: yes — users invoke via /wod-type
#   - auto-trigger: yes — Claude invokes when asked to add a new workout type
#   - subagent: no
#   - cross-skill: no
---

# Add New Workout Type

Adding a workout type touches **5 files in a specific order**. Missing any step silently breaks classification or evaluation.

## Step-by-Step Checklist

### Step 1: Add enum value
**File**: `backend/app/schemas/workout.py`

Add to `WorkoutType(str, Enum)`:
```python
YOUR_TYPE = "your_type"
```

Existing values: `amrap`, `emom`, `for_time`, `tabata`, `intervals`, `stopwatch`, `custom`

---

### Step 2: Create prompt file
**File**: `backend/app/prompts/{type}.py`

Use the `wod-prompt` skill for the correct format. Template:
```python
"""Your Type workout prompt."""

YOUR_TYPE_PROMPT = """YOUR_TYPE = Full name.

CONCEPT:
- ...

RULES:
- ...

EXAMPLES:

"example workout text"
→ intervals: [...]
→ movements: [...]"""
```

---

### Step 3: Register in prompt manager
**File**: `backend/app/prompts/prompt_manager.py`

Add import:
```python
from app.prompts.{type} import YOUR_TYPE_PROMPT
```

Add to `self._prompts` dict in `__init__`:
```python
WorkoutType.YOUR_TYPE: YOUR_TYPE_PROMPT,
```

---

### Step 4: Add classification keywords
**File**: `backend/app/services/workout_type_classifier.py`

Add to `_setup_default_keywords()`:
```python
self._keyword_config[WorkoutType.YOUR_TYPE] = WorkoutTypeKeywords(
    keywords=[
        "keyword1",  # plain substring matches
        "keyword2",
    ],
    patterns=[
        r"regex_pattern\d+",  # regex patterns (more specific = +3 pts each)
    ],
    priority=8,  # 10=high, 8=medium, 3=low
)
```

**Scoring**: `priority + (keyword_matches × 2) + (pattern_matches × 3)` — higher wins.

---

### Step 5: Create promptfoo evaluation config
**File**: `promptfoo/{type}.yaml`

Use the `promptfoo-eval` skill for the correct format. At minimum:
```yaml
description: 'YOUR_TYPE Workout Parser Tests'

prompts:
  - file://prompts/{type}.txt

providers:
  - id: openai:gpt-4o
    config:
      max_tokens: 2000
      response_format:
        type: json_object

tests:
  - description: "Basic {type} test"
    vars:
      workout_text: "..."
    assert:
      - type: is-json
      - type: javascript
        value: 'JSON.parse(output).workout_type === "your_type"'
      - type: javascript
        value: 'JSON.parse(output).intervals.length === N'
```

---

## Verification

```bash
# Run tests for the new type
python scripts/run_tests.py --type {type}

# Smoke test the API
curl -X POST http://localhost:8000/api/v1/timer/parse \
  -H "Content-Type: application/json" \
  -d '{"workout_text": "your example workout"}'
```

Check the response `workout_type` field matches your new enum value exactly.

## Notes

- If you add timer_config handling, check `ParsedWorkout.timer_config` in `backend/app/schemas/workout.py` — it branches on `WorkoutType` enum values
- `CUSTOM` is the fallback for unrecognized types — no need to handle missing types explicitly
- Priority 10 = high confidence types (AMRAP, EMOM, TABATA), 8 = medium (FOR_TIME, INTERVALS), 3 = low (STOPWATCH)
