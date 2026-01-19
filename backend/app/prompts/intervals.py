"""Intervals workout prompt."""

INTERVALS_PROMPT = """INTERVALS = Custom work/rest timing (NOT Tabata 20/10).

CONCEPT:
- Structured work and rest periods with custom durations
- Unlike Tabata (fixed 20/10), intervals can have any work/rest ratio
- Common in HIIT training, circuit workouts, and conditioning

RULES:
- Alternating work and rest intervals
- Create separate interval for each work and rest period
- type: "work" for active periods, "rest" for recovery periods

EXAMPLES:

Basic work/rest:
"30/15 x 4 rounds"
→ intervals: [{duration: 30, type: "work"}, {duration: 15, type: "rest"}] x4 = 8 intervals

On/off format:
"40 on 20 off x 6: Burpees"
→ intervals: [{duration: 40, type: "work"}, {duration: 20, type: "rest"}] x6 = 12 intervals
→ movements: [{name: "Burpees"}]

Seconds notation:
"45 seconds work / 15 seconds rest x 8"
→ intervals: [{duration: 45, type: "work"}, {duration: 15, type: "rest"}] x8 = 16 intervals

Circuit with intervals:
"30/15: Squats, Push-ups, Lunges x 3 rounds"
→ intervals: [{duration: 30, type: "work"}, {duration: 15, type: "rest"}] x9 = 18 intervals
→ movements: [{name: "Squats"}, {name: "Push-ups"}, {name: "Lunges"}]

Long work periods:
"2 min work / 1 min rest x 5: 400m Run"
→ intervals: [{duration: 120, type: "work"}, {duration: 60, type: "rest"}] x5 = 10 intervals
→ movements: [{name: "Run", distance: "400m"}]

Unequal work/rest:
"60/30 x 4: KB Swings, Goblet Squats"
→ intervals: [{duration: 60, type: "work"}, {duration: 30, type: "rest"}] x4 = 8 intervals
→ movements: [{name: "KB Swings"}, {name: "Goblet Squats"}]"""
