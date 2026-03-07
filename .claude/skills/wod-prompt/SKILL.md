---
name: wod-prompt
description: "Workout parser prompt author for ai-wod-timer. Use when editing backend/app/prompts/*.py files, improving parsing accuracy, or writing type-specific AI prompt instructions. Triggers on: editing a prompt, prompt for AMRAP/EMOM/tabata/for_time, backend/app/prompts/, improve parsing accuracy."
# consumers:
#   - standalone: yes — users invoke via /wod-prompt
#   - auto-trigger: yes — Claude invokes when editing prompts/ files or discussing parsing accuracy
#   - subagent: no
#   - cross-skill: yes — referenced by wod-type when creating a new prompt file
---

# WOD Prompt Author

You are helping edit or create a workout parser prompt in `backend/app/prompts/`.

## Architecture

Prompts use a **base + type layering** system. The system prompt sent to the LLM is:

```
{type_prompt}\n\n{base_prompt_with_schema}
```

- `base.py` — defines the JSON output schema, number handling rules, time parsing rules
- `{type}.py` — type-specific concept explanation, rules, and examples
- `prompt_manager.py` — combines them via `get_system_prompt(workout_type)`

## JSON Output Schema (from base.py)

```json
{
  "workout_type": "string (copy exactly from input context)",
  "movements": [...],
  "intervals": [...],
  "ai_interpretation": "string"
}
```

### Movement fields (only include relevant fields):
```json
{"name": "string", "reps": number}
{"name": "string", "duration": number}
{"name": "string", "distance": "string"}
{"name": "string", "calories": number}
{"name": "string", "reps": number, "weight": "string"}
{"name": "string", "reps": number, "weight": "string", "distance": "string"}
```

### Interval fields:
```json
{"duration": number, "type": "work"}
{"duration": number, "type": "rest"}
{"duration": number, "type": "work", "repeat": true}
```

## Critical Base Rules (DO NOT violate)

1. `duration` is always in **seconds** (60s = 1min, 600s = 10min, 1200s = 20min)
2. `duration = 0` means stopwatch/count-up mode — do NOT infer from reps/weight/distance
3. No rest intervals unless text explicitly states rest/pause/break
4. `intervals` array MUST NOT contain a `movements` field
5. Named complexes (Cindy, DT, Macho Man) are NOT movements — extract their constituent exercises
6. `workout_type` must match the provided context byte-for-byte

## Per-Type Interval Structure

| Type | Interval pattern |
|------|-----------------|
| AMRAP | Single `{duration: N, type: "work"}` — no rest at end |
| EMOM | N separate `{duration: 60, type: "work"}` intervals; E2MOM=120s, E3MOM=180s |
| FOR_TIME | Single interval; `duration=0` if no cap, `duration=cap_in_seconds` if capped |
| TABATA | 16 alternating intervals: `{20, work}, {10, rest}` × 8 |
| INTERVALS | Alternating work/rest pairs based on stated work:rest ratio |
| STOPWATCH | `[{duration: 0, type: "work"}]` |
| CUSTOM | Parse as described, use `duration=0` for unstated times |

## Common Prompt Mistakes

- **EMOM**: Generating one long interval instead of N×60s intervals
- **TABATA**: Multiplying duration instead of creating 16 separate interval objects
- **FOR_TIME with cap**: Forgetting that time cap = interval duration (not 0)
- **AMRAP with rest**: Adding trailing rest interval at the end (no rest after last AMRAP)
- **Named complex**: Including the complex name as a movement instead of its component exercises

## Type-Specific Prompt File Pattern

```python
"""Type description."""

TYPE_PROMPT = """TYPE = Full name.

CONCEPT:
- ...

RULES:
- ...

EXAMPLES:

Description:
"raw workout text"
→ intervals: [...]
→ movements: [...]"""
```

## Post-Edit Checklist

1. Run prompt generation: `python scripts/generate_prompts.py`
2. Run type tests: `python scripts/run_tests.py --type {type}`
3. Check `ai_interpretation` field in output for model reasoning
4. Verify edge cases: no explicit duration (should be 0), named complexes, weighted movements
