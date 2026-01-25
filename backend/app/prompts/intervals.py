"""Intervals workout prompt."""

INTERVALS_PROMPT = """INTERVALS = Custom work/rest timing (NOT Tabata 20/10).

CONCEPT:
- Structured work and rest periods with custom durations
- Unlike Tabata (fixed 20/10), intervals can have any work/rest ratio
- Common in HIIT training, circuit workouts, and conditioning

RULES:
- Alternating work and rest intervals
- Create separate interval object for each work and rest period
- type: "work" for active periods, "rest" for recovery periods
- NEVER multiply durations - create separate interval objects

EXAMPLES:

Basic work/rest (4 rounds = 8 intervals):
"30/15 x 4 rounds"
→ intervals: [
    {duration: 30, type: "work"}, {duration: 15, type: "rest"},
    {duration: 30, type: "work"}, {duration: 15, type: "rest"},
    {duration: 30, type: "work"}, {duration: 15, type: "rest"},
    {duration: 30, type: "work"}, {duration: 15, type: "rest"}
]

On/off format (6 rounds = 12 intervals):
"40 on 20 off x 6: Burpees"
→ intervals: [
    {duration: 40, type: "work"}, {duration: 20, type: "rest"},
    {duration: 40, type: "work"}, {duration: 20, type: "rest"},
    {duration: 40, type: "work"}, {duration: 20, type: "rest"},
    {duration: 40, type: "work"}, {duration: 20, type: "rest"},
    {duration: 40, type: "work"}, {duration: 20, type: "rest"},
    {duration: 40, type: "work"}, {duration: 20, type: "rest"}
]
→ movements: [{name: "Burpees"}]

Long work periods (5 rounds = 10 intervals):
"2 min work / 1 min rest x 5: 400m Run"
→ intervals: [
    {duration: 120, type: "work"}, {duration: 60, type: "rest"},
    {duration: 120, type: "work"}, {duration: 60, type: "rest"},
    {duration: 120, type: "work"}, {duration: 60, type: "rest"},
    {duration: 120, type: "work"}, {duration: 60, type: "rest"},
    {duration: 120, type: "work"}, {duration: 60, type: "rest"}
]
→ movements: [{name: "Run", distance: "400m"}]

Unequal work/rest (4 rounds = 8 intervals):
"60/30 x 4: KB Swings, Goblet Squats"
→ intervals: [
    {duration: 60, type: "work"}, {duration: 30, type: "rest"},
    {duration: 60, type: "work"}, {duration: 30, type: "rest"},
    {duration: 60, type: "work"}, {duration: 30, type: "rest"},
    {duration: 60, type: "work"}, {duration: 30, type: "rest"}
]
→ movements: [{name: "KB Swings"}, {name: "Goblet Squats"}]"""
