---
name: wod-debug
description: "Debug AI parsing failures in ai-wod-timer's two-stage pipeline. Use when parsing returns wrong result, wrong workout type detected, incorrect intervals, or AI misidentified the workout. Triggers on: parsing wrong, wrong workout type detected, incorrect intervals, AI misidentified, debug timer, fix parsing."
# consumers:
#   - standalone: yes — users invoke via /wod-debug
#   - auto-trigger: yes — Claude invokes when debugging parse failures
#   - subagent: no
#   - cross-skill: no
---

# WOD Debug: AI Parsing Failure Triage

## Pipeline Overview

```
User text
  → WorkoutTypeClassifier (regex/keywords, no AI) → WorkoutType enum
  → PromptManager.get_system_prompt(type) → system_prompt
  → OpenAI (parser agent or direct call) → JSON
  → ParsedWorkout (validation)
```

Two failure modes: **wrong type** (classifier) or **wrong structure** (prompt/LLM).

## Triage Flowchart

### 1. Was the wrong workout type detected?

Check: does `workout_type` in the response match what you expected?

**Yes, wrong type** → Fix: `backend/app/services/workout_type_classifier.py`
- Find the matching type's `WorkoutTypeKeywords` config
- Add missing keywords to `keywords: []`
- Add missing patterns to `patterns: []` (regex, +3pts each hit)
- Increase `priority` if it's losing to another type
- Scoring: `priority + (keyword_matches × 2) + (pattern_matches × 3)` — highest wins

**No, type is correct** → Problem is in the prompt or LLM → continue to step 2

---

### 2. Is the JSON structure wrong?

Check: are the top-level fields present? Is `intervals` inside `movements`? Is `workout_type` missing?

**Yes, structural issue** → Fix: `backend/app/prompts/base.py`
- Check `BASE_SYSTEM_PROMPT` rules and schema definition
- These rules apply to ALL workout types

---

### 3. Are the intervals wrong (wrong count, wrong duration, wrong type)?

**Yes, interval logic issue** → Fix: `backend/app/prompts/{type}.py`
- Compare your input against the examples in the prompt file
- Common issues:
  - EMOM: one big interval instead of N×60s → check "RULES" section
  - TABATA: 8 intervals instead of 16 → check "RULES" section
  - FOR_TIME: duration=0 when there's a cap → check cap handling
  - AMRAP: trailing rest interval → examples should show no rest at end

---

### 4. Are the movements wrong?

**Named complex extracted as movement** → Fix: add complex to `NAMED COMPLEXES` section in `base.py`

**Movement fields wrong** (reps vs duration vs distance) → Fix: improve examples in `{type}.py`

---

## Isolation Techniques

### Direct API call (bypass frontend)
```bash
curl -X POST http://localhost:8000/api/v1/timer/parse \
  -H "Content-Type: application/json" \
  -d '{"workout_text": "EMOM 10: 5 pull-ups, 10 push-ups"}'
```

Check `ai_interpretation` field — the model explains its own reasoning there.

### Force agent vs. non-agent
```bash
# Force agent pipeline (two-stage: classifier → parser)
curl "...?use_agent=true"

# Force direct parse (single-pass)
curl "...?use_agent=false"
```

### Environment flags (in `backend/.env`)
```env
USE_AGENT_WORKFLOW=False       # True = two-stage agent; False = single-pass parser
USE_CUSTOM_PROMPT_ONLY=False   # True = ignores type-specific prompts, uses custom.py for all
```

Use `USE_CUSTOM_PROMPT_ONLY=True` to test if the issue is in the type-specific prompt vs. base schema.

---

## Key Files

| Problem | File |
|---------|------|
| Wrong type classified | `backend/app/services/workout_type_classifier.py` |
| Wrong interval logic | `backend/app/prompts/{type}.py` |
| Wrong JSON structure | `backend/app/prompts/base.py` |
| Type not registered | `backend/app/prompts/prompt_manager.py` |
| Agent pipeline bug | `backend/app/services/agent_workflow.py` |
| Non-agent parser bug | `backend/app/services/workout_parser.py` |
| Config flags | `backend/app/config.py` + `backend/.env` |

---

## Verify Fix

```bash
# Re-run promptfoo tests for the affected type
python scripts/run_tests.py --type {type}

# Or test manually via API
curl -X POST http://localhost:8000/api/v1/timer/parse \
  -H "Content-Type: application/json" \
  -d '{"workout_text": "your problem input"}'
```
