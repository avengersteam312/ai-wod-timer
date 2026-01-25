"""EMOM (Every Minute On the Minute) workout prompt."""

EMOM_PROMPT = """EMOM = Every Minute On the Minute.

CONCEPT:
- Athlete performs prescribed work at the start of each interval
- Remaining time in the interval is rest before next round begins
- Each interval is SEPARATE (not one combined interval)

RULES:
- EMOM = 60 seconds per interval
- E2MOM = 120 seconds per interval
- E3MOM = 180 seconds per interval
- E[N]MOM = N * 60 seconds per interval
- "EMOM xN:00" generates N separate work intervals of 60 seconds each

EXAMPLES:

EMOM 10 min = 10 intervals of 60s each):
"EMOM 10: 5 Pull-ups, 10 Push-ups"
→ intervals: [
    {duration: 60, type: "work"},
    {duration: 60, type: "work"},
    {duration: 60, type: "work"},
    {duration: 60, type: "work"},
    {duration: 60, type: "work"},
    {duration: 60, type: "work"},
    {duration: 60, type: "work"},
    {duration: 60, type: "work"},
    {duration: 60, type: "work"},
    {duration: 60, type: "work"}
]
→ movements: [{name: "Pull-ups", reps: 5}, {name: "Push-ups", reps: 10}]

E2MOM (12 min = 6 intervals of 120s each):
"E2MOM 12 min: 3 Power Cleans 155#, 6 Bar Facing Burpees"
→ intervals: [
    {duration: 120, type: "work"},
    {duration: 120, type: "work"},
    {duration: 120, type: "work"},
    {duration: 120, type: "work"},
    {duration: 120, type: "work"},
    {duration: 120, type: "work"}
]
→ movements: [{name: "Power Cleans", reps: 3, weight: "155#"}, {name: "Bar Facing Burpees", reps: 6}]

E3MOM (15 min = 5 intervals of 180s each):
"E3MOM x 15: 400m Run"
→ intervals: [
    {duration: 180, type: "work"},
    {duration: 180, type: "work"},
    {duration: 180, type: "work"},
    {duration: 180, type: "work"},
    {duration: 180, type: "work"}
]
→ movements: [{name: "Run", distance: "400m"}]

Every 90 seconds (9 min = 6 intervals of 90s each):
"Every 90 sec for 9 min: 5 Deadlifts 225#"
→ intervals: [
    {duration: 90, type: "work"},
    {duration: 90, type: "work"},
    {duration: 90, type: "work"},
    {duration: 90, type: "work"},
    {duration: 90, type: "work"},
    {duration: 90, type: "work"}
]
→ movements: [{name: "Deadlifts", reps: 5, weight: "225#"}]

EMOM until failure with cap (10 min cap = 10 intervals of 60s each):
"EMOM until failure, 3 power cleans, 3 front squats, 3 jerks, CAP: 10:00"
→ intervals: [
    {duration: 60, type: "work"},
    {duration: 60, type: "work"},
    {duration: 60, type: "work"},
    {duration: 60, type: "work"},
    {duration: 60, type: "work"},
    {duration: 60, type: "work"},
    {duration: 60, type: "work"},
    {duration: 60, type: "work"},
    {duration: 60, type: "work"},
    {duration: 60, type: "work"}
]
→ movements: [{name: "Power Cleans", reps: 3}, {name: "Front Squats", reps: 3}, {name: "Jerks", reps: 3}]

Rotating EMOM with 30s work/30s rest (12 min = 24 intervals):
"EMOM x12:00, Min 1-4: 30s max rope climbs, Min 5-8: 30s max half GHD sit ups, Min 9-12: 30s max pistol squats"
→ intervals: [
    {duration: 30, type: "work"}, {duration: 30, type: "rest"},
    {duration: 30, type: "work"}, {duration: 30, type: "rest"},
    {duration: 30, type: "work"}, {duration: 30, type: "rest"},
    {duration: 30, type: "work"}, {duration: 30, type: "rest"},
    {duration: 30, type: "work"}, {duration: 30, type: "rest"},
    {duration: 30, type: "work"}, {duration: 30, type: "rest"},
    {duration: 30, type: "work"}, {duration: 30, type: "rest"},
    {duration: 30, type: "work"}, {duration: 30, type: "rest"},
    {duration: 30, type: "work"}, {duration: 30, type: "rest"},
    {duration: 30, type: "work"}, {duration: 30, type: "rest"},
    {duration: 30, type: "work"}, {duration: 30, type: "rest"},
    {duration: 30, type: "work"}, {duration: 30, type: "rest"}
]
→ movements: [{name: "Rope Climbs"}, {name: "Half GHD Sit Ups"}, {name: "Pistol Squats"}]

EMOM ladder until failure (no cap = single interval that repeats):
"Every minute until failure 1-2-3-4-5-6-7-8-9-10-etc... strict HSPU"
→ intervals: [{duration: 60, type: "work", repeat: true}]
→ movements: [{name: "Strict HSPU", reps: 1}]"""
