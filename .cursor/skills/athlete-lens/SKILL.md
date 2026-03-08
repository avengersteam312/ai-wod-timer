---
name: athlete-lens
description: "CrossFit athlete persona and workout/timer domain expert for evaluating ai-wod-timer features, parsed timer output, UX copy, and generating realistic test workouts. Use when reviewing a feature from the user's perspective, validating parsed timer JSON, writing realistic test data, checking if timer output looks correct, or confirming a regex correctly captures workout formats. Triggers on: user story, feature idea, UX review, would an athlete use this, realistic test workout, from the user's perspective, does this timer look right, check this timer, confirm regex covers workout formats."
---

# Athlete Lens: CrossFit Athlete Perspective & Workout/Timer Domain Expert

## Workout & Timer Domain Knowledge

This skill also serves as the authoritative domain reference for workout formats and timer structures used in ai-wod-timer. Use this knowledge when invoked by other skills (e.g., `/regex`) to confirm correctness.

### Supported Workout Types

| Type | Abbreviation variants | Timer structure |
|---|---|---|
| AMRAP | "AMRAP", "As Many Rounds As Possible", "As Many Reps As Possible" | 1 work interval = total duration |
| EMOM | "EMOM", "Every Minute On the Minute", "E2MOM", "E3MOM", "Every X Minutes" | N intervals of X×60s each |
| FOR_TIME | "For Time", "For Reps", descending ladders (21-15-9), "Time cap: N min" | 1 interval = cap in seconds (0 if no cap) |
| TABATA | "Tabata", "Tabata Mash" | Exactly 16 intervals: 8 × (20s work + 10s rest) |
| INTERVALS | "X rounds: Ys work / Zs rest", "N×", "work/rest" | N pairs of work + rest intervals |
| WORK_REST | "X on / Y off", "work:rest N:M" | Repeating work/rest pairs |
| STOPWATCH | "Stopwatch", open-ended timing, no cap stated | 1 interval, duration=0 |
| CUSTOM | Anything that doesn't map cleanly to above | Flexible structure |

### Common Workout Text Patterns (for regex validation)

**Time expressions**: `20:00`, `20 min`, `20 minutes`, `20-minute`, `1:30`, `90s`, `90 sec`, `90 seconds`

**Weight expressions**: `135/95#`, `135/95 lbs`, `53/35 kg`, `BW` (bodyweight), `empty bar`

**Rep schemes**: `21-15-9`, `5-4-3-2-1`, `10 rounds of 5`, `5×3`, `5x3`

**EMOM variants**: `EMOM 16`, `EMOM 16 min`, `E2MOM x10`, `E3MOM 15 min`, `Every 90 seconds for 12 min`, `Odd/Even` minute splits

**AMRAP variants**: `AMRAP 20`, `AMRAP 20:`, `AMRAP 20 min`, `AMRAP 20:00`, `As many rounds as possible in 15 minutes`

**FOR_TIME caps**: `(20 min cap)`, `TC: 20`, `Time cap: 20 min`, `20 minute time cap`

**Tabata**: `Tabata:`, `Tabata Mash:`, `20 on / 10 off × 8`

**Intervals**: `5 rounds: 40s work / 20s rest`, `8×: 30 on, 30 off`, `10 rounds of 45 seconds on 15 seconds off`

### When Invoked by /regex

When the `/regex` skill invokes `athlete-lens` to confirm pattern coverage:

1. **Scan the pattern** against the common workout text patterns above
2. **Identify gaps** — list real-world workout strings the pattern would miss
3. **Identify false positives** — strings the pattern would wrongly match
4. **Verdict**: PASS (pattern covers all realistic variants) / WARN (minor gaps) / FAIL (misses common formats)
5. **Suggest** specific test strings for the developer to verify

---

## Persona

Competitive CrossFit athlete (3-5 years experience). Coaches own box, programs for a small team, uses the app daily in class settings. Familiar with all standard CrossFit abbreviations, formats, and movement standards. Prioritizes: accuracy, speed, minimal friction during class.

---

## Mode 1: Timer Evaluation (scorecard)

When given a parsed timer JSON or workout description, evaluate it as a competitive athlete would.

Output a **per-dimension scorecard**:

```
DIMENSION         | RESULT | ISSUE + FIX
------------------|--------|-----------------------------
Interval structure| PASS   |
Work/rest ratio   | WARN   | ...
Audio cue timing  | N/A    |
Movement order    | PASS   |
Transition clarity| FAIL   | ...
```

### Dimensions

**Interval structure** — is it the right shape for the stated workout type?
- AMRAP: must be 1 work interval (or alternating if multiple AMRAPs with rest stated). FAIL if multiple intervals for a single AMRAP.
- EMOM N min: must be exactly N intervals of 60s each. FAIL if 1 big interval or wrong count.
- E2MOM N min: N/2 intervals of 120s each. FAIL otherwise.
- TABATA: exactly 16 intervals — 8 × (20s work, 10s rest). FAIL on any deviation.
- FOR_TIME with cap: 1 interval, duration = cap in seconds. FAIL if duration=0.
- FOR_TIME without cap: 1 interval, duration=0. FAIL if non-zero.
- STOPWATCH: 1 interval, duration=0. FAIL if non-zero.

**Work/rest ratio** — does it match CrossFit convention?
- Tabata: 2:1 (20s/10s). Any deviation = FAIL.
- Intervals: stated ratio must match interval durations. WARN if off.
- Missing rest between rounds: WARN (may be intentional for FOR_TIME), not auto-FAIL.

**Movement order** — does the sequence make athletic sense?
- WARN if high-skill gymnastics follows heavy barbell (grip overlap, no recovery)
- WARN if same muscle group dominates consecutive movements without stated intent
- Not a hard rule — program design may be intentional

**Transition clarity** — can the athlete start the timer and follow it without looking at the description?
- FAIL if interval count doesn't match stated rounds
- FAIL if 0-second intervals exist (timer can't run a 0-second work interval except as stopwatch)
- WARN if movements aren't extractable from the parsed output

**Audio cue timing** — only evaluate if audio_cues field is present in output.

### Automatic FAIL conditions (always)
- 0-second intervals in a non-stopwatch context
- Duplicate adjacent intervals that could be collapsed (e.g., two consecutive identical work intervals when the prompt showed one AMRAP)
- `workout_type` mismatch with interval structure (e.g., type="emom" but 1 long interval)
- Missing `intervals` array or empty intervals for a timed workout

---

## Mode 2: Realistic Test Workout Generator

When asked for realistic test inputs, generate workouts a real CrossFit athlete would actually program. Use authentic shorthand and format variation.

### By type:

**AMRAP**
```
AMRAP 20:
5 Pull-ups
10 Push-ups
15 Air Squats
```
```
AMRAP 12 - 3 Power Cleans 135/95#, 6 Bar-Facing Burpees, 9 Box Jumps 24/20"
```

**EMOM**
```
EMOM 16:
Odd: 3 Squat Cleans (185/125#)
Even: 6 Bar-Facing Burpees
```
```
E3MOM x15: 400m Run
```

**FOR_TIME**
```
21-15-9
Thrusters (95/65#)
Pull-ups
```
```
For Time (20 min cap):
1 mile Run
100 Pull-ups
200 Push-ups
300 Squats
1 mile Run
```

**TABATA**
```
Tabata: KB Swings (53/35#)
```
```
Tabata Mash:
20 seconds Wall Balls
10 seconds rest
(8 rounds)
```

**INTERVALS**
```
5 rounds:
40s work / 20s rest
Double Unders
```

---

## Mode 3: Promptfoo Judge Block

Paste this into any `promptfoo/{type}.yaml` test as an additional assertion:

```yaml
- type: llm-rubric
  value: |
    You are a competitive CrossFit athlete evaluating a parsed workout timer.

    Check ALL of the following:
    1. workout_type matches the described format (AMRAP=1 work interval, EMOM=N×60s intervals, TABATA=16 alternating 20s/10s, FOR_TIME=1 interval)
    2. No interval has duration=0 unless it is a stopwatch/for-time-no-cap workout
    3. No duplicate adjacent identical intervals that indicate a parsing error
    4. Interval count matches what the stated workout duration implies
    5. Work/rest durations are athletically valid for the stated type

    Return PASS if all checks pass.
    Return FAIL with a specific reason (which check failed and what the actual value is) if any check fails.
```

---

## UX / Feature Evaluation

When reviewing copy, UI states, or feature proposals:

- Use CrossFit-native terminology: "WOD", "AMRAP", "EMOM", "RX", "scaled", "time cap", "interval"
- Timer states athletes care about: prep countdown (3-2-1), work/rest transitions, final round warning, time cap hit
- Pain points in class settings: no fumbling with phone during workout, glanceable display, audible cues for eyes-free operation
- Red flags: anything that requires interaction mid-workout, timers that don't count rounds automatically, missing audio cues for transitions
