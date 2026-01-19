"""For Time workout prompt."""

FOR_TIME_PROMPT = """FOR TIME = Complete all work as fast as possible.

CONCEPT:
- Athlete completes prescribed work in minimum time
- Goal is to finish all movements/rounds as quickly as possible
- Time cap limits maximum duration (optional)
- Always 1 single interval regardless of rounds or rep schemes

RULES:
- With time cap: 1 interval with duration = time cap in seconds
- Without time cap: 1 interval with duration = 0 (stopwatch mode)
- type: "work" (always)
- "21-15-9" = descending rep scheme (still 1 interval, not 3)
- "5 RFT" = 5 rounds for time (still 1 interval)
- Rep schemes describe the work, not separate intervals

EXAMPLES:

With time cap:
"For Time (15 min cap): 50 Wall Balls, 40 Box Jumps, 30 KB Swings"
→ intervals: [{duration: 900, type: "work"}]
→ movements: [{name: "Wall Balls", reps: 50}, {name: "Box Jumps", reps: 40}, {name: "KB Swings", reps: 30}]

Without time cap (stopwatch):
"For Time: 100 Burpees"
→ intervals: [{duration: 0, type: "work"}]
→ movements: [{name: "Burpees", reps: 100}]

Rounds for time:
"5 RFT: 10 Deadlifts 225#, 15 Box Jumps"
→ intervals: [{duration: 0, type: "work"}]
→ movements: [{name: "Deadlifts", reps: 10, weight: "225#"}, {name: "Box Jumps", reps: 15}]

Descending rep scheme:
"21-15-9 For Time: Thrusters 95#, Pull-ups"
→ intervals: [{duration: 0, type: "work"}]
→ movements: [{name: "Thrusters", reps: 21, weight: "95#"}, {name: "Pull-ups", reps: 21}]

With distance:
"For Time (20 min cap): 1 mile Run, 100 Pull-ups, 200 Push-ups, 300 Squats, 1 mile Run"
→ intervals: [{duration: 1200, type: "work"}]
→ movements: [{name: "Run", distance: "1 mile"}, {name: "Pull-ups", reps: 100}, {name: "Push-ups", reps: 200}, {name: "Squats", reps: 300}, {name: "Run", distance: "1 mile"}]

Chipper style:
"For Time: 50 Cal Row, 40 Toes to Bar, 30 Wall Balls, 20 Clean & Jerks 135#, 10 Muscle-ups"
→ intervals: [{duration: 0, type: "work"}]
→ movements: [{name: "Cal Row", calories: 50}, {name: "Toes to Bar", reps: 40}, {name: "Wall Balls", reps: 30}, {name: "Clean & Jerks", reps: 20, weight: "135#"}, {name: "Muscle-ups", reps: 10}]"""
