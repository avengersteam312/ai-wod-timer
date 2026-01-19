"""Stopwatch workout prompt."""

STOPWATCH_PROMPT = """STOPWATCH = Open-ended timer counting UP from 0.

CONCEPT:
- Timer counts up indefinitely with no preset end time
- Used for tracking personal records, open practice, or untimed work
- Athlete controls when to stop
- No time pressure - focus on quality or just recording completion time

INTERVAL STRUCTURE:
- Always 1 single interval
- duration: 0 (signals count-up/stopwatch mode)
- type: "work"

EXAMPLES:

Practice/skill work:
"Stopwatch: Practice handstands"
→ intervals: [{duration: 0, type: "work"}]
→ movements: [{name: "Handstands"}]

Track completion time:
"Track time: 100 Burpees"
→ intervals: [{duration: 0, type: "work"}]
→ movements: [{name: "Burpees", reps: 100}]

Open workout:
"Untimed: 5x5 Back Squat"
→ intervals: [{duration: 0, type: "work"}]
→ movements: [{name: "Back Squat", reps: 5}]

Personal record attempt:
"Record time: 2000m Row"
→ intervals: [{duration: 0, type: "work"}]
→ movements: [{name: "Row", distance: "2000m"}]

Mixed movements no time limit:
"Open timer: 50 Double Unders, 40 Sit-ups, 30 KB Swings"
→ intervals: [{duration: 0, type: "work"}]
→ movements: [{name: "Double Unders", reps: 50}, {name: "Sit-ups", reps: 40}, {name: "KB Swings", reps: 30}]

Strength session:
"Count up: 5x3 Deadlift 315#"
→ intervals: [{duration: 0, type: "work"}]
→ movements: [{name: "Deadlift", reps: 3, weight: "315#"}]"""
