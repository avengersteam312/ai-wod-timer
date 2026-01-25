"""AMRAP (As Many Rounds As Possible) workout prompt."""

AMRAP_PROMPT = """AMRAP = As Many Rounds As Possible within a time limit.

CONCEPT:
- Athlete performs a set of movements repeatedly for a fixed time
- Goal is to complete as many rounds/reps as possible before time expires
- No rest intervals - continuous work for the entire duration

RULES:
- Single AMRAP: 1 work interval for the entire duration
- Multiple AMRAPs with rest: alternate work and rest intervals
- type: "work" for AMRAP periods, "rest" for recovery periods
- duration: time in seconds

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
→ movements: [{name: "Run", distance: "400m"}, {name: "Thrusters", reps: 15, weight: "95#"}, {name: "Cal Bike", calories: 12}]

Multiple AMRAPs with rest (3 x 5:00 AMRAP with 3:00 rest = 5 intervals):
"For Max Reps: AMRAP x5:00 500/400m row, in remainder time 10 toes to bar, 10 thrusters, rest 3:00, AMRAP x5:00 500/400m row, in remainder time 8 chest to bar pull ups, 8 thrusters, rest 3:00, AMRAP x5:00 500/400m row, in remainder time 6 bar muscle ups, 6 thrusters"
→ intervals: [
    {duration: 300, type: "work"},
    {duration: 180, type: "rest"},
    {duration: 300, type: "work"},
    {duration: 180, type: "rest"},
    {duration: 300, type: "work"}
]
→ movements: [{name: "Row", distance: "500/400m"}, {name: "Toes to Bar", reps: 10}, {name: "Thrusters", reps: 10}, {name: "Chest to Bar Pull Ups", reps: 8}, {name: "Bar Muscle Ups", reps: 6}]"""
