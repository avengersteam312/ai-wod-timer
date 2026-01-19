"""AMRAP (As Many Rounds As Possible) workout prompt."""

AMRAP_PROMPT = """AMRAP = As Many Rounds As Possible within a time limit.

CONCEPT:
- Athlete performs a set of movements repeatedly for a fixed time
- Goal is to complete as many rounds/reps as possible before time expires
- No rest intervals - continuous work for the entire duration

RULES:
- Always 1 single work interval for the entire duration
- type: "work" (never rest for AMRAP)
- duration: total time in seconds

EXAMPLES:

Rep-based movements:
"AMRAP 12: 10 KB Swings, 15 Box Jumps"
→ intervals: [{duration: 720, type: "work"}]
→ movements: [{name: "KB Swings", reps: 10}, {name: "Box Jumps", reps: 15}]

Weighted movements:
"AMRAP 7 - 3 Power Cleans 135#, 5 Burpees"
→ intervals: [{duration: 420, type: "work"}]
→ movements: [{name: "Power Cleans", reps: 3, weight: "135#"}, {name: "Burpees", reps: 5}]

Distance-based movements:
"As many rounds as possible in 15 minutes: 200m Run, 10 Deadlifts"
→ intervals: [{duration: 900, type: "work"}]
→ movements: [{name: "Run", distance: "200m"}, {name: "Deadlifts", reps: 10}]

Calorie-based movements:
"AMRAP 10:00 - 12 Cal Row, 8 Push-ups"
→ intervals: [{duration: 600, type: "work"}]
→ movements: [{name: "Cal Row", calories: 12}, {name: "Push-ups", reps: 8}]

Time-based movements:
"Max rounds 8 min: 30 sec plank hold, 10 Squats"
→ intervals: [{duration: 480, type: "work"}]
→ movements: [{name: "Plank Hold", duration: 30}, {name: "Squats", reps: 10}]

Mixed movement types:
"AMRAP 20: 400m Run, 15 Thrusters 95#, 12 Cal Bike"
→ intervals: [{duration: 1200, type: "work"}]
→ movements: [{name: "Run", distance: "400m"}, {name: "Thrusters", reps: 15, weight: "95#"}, {name: "Cal Bike", calories: 12}]"""
