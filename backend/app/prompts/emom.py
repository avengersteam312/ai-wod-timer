"""EMOM (Every Minute On the Minute) workout prompt."""

EMOM_PROMPT = """EMOM = Every Minute On the Minute.

CONCEPT:
- Athlete performs prescribed work at the start of each interval
- Remaining time in the interval is rest before next round begins
- Each interval is SEPARATE (not one combined interval)

!!! CRITICAL !!!
- NEVER create work intervals longer than 60 seconds for standard EMOM
- ALWAYS split "EMOM xN:00" into N separate 60-second work intervals

RULES:
- EMOM = 60 seconds per interval
- E2MOM = 120 seconds per interval
- E3MOM = 180 seconds per interval
- E[N]MOM = N * 60 seconds per interval
- "EMOM xN:00" generates N separate work intervals of 60 seconds each

EXAMPLES:

Standard EMOM:
"EMOM 10: 5 Pull-ups, 10 Push-ups"
→ intervals: [{duration: 60, type: "work"}, {duration: 60, type: "work"}, ... x10]
→ movements: [{name: "Pull-ups", reps: 5}, {name: "Push-ups", reps: 10}]

E2MOM (every 2 minutes):
"E2MOM 12 min: 3 Power Cleans 155#, 6 Bar Facing Burpees"
→ intervals: [{duration: 120, type: "work"}, {duration: 120, type: "work"}, ... x6]
→ movements: [{name: "Power Cleans", reps: 3, weight: "155#"}, {name: "Bar Facing Burpees", reps: 6}]

E3MOM (every 3 minutes):
"E3MOM x 15: 400m Run"
→ intervals: [{duration: 180, type: "work"}, {duration: 180, type: "work"}, ... x5]
→ movements: [{name: "Run", distance: "400m"}]

Alternating EMOM:
"EMOM 12 - Odd: 15 Cal Row, Even: 12 KB Swings"
→ intervals: [{duration: 60, type: "work"}, {duration: 60, type: "work"}, ... x12]
→ movements: [{name: "Cal Row", calories: 15}, {name: "KB Swings", reps: 12}]

EMOM with explicit rest:
"EMOM x5:00, rest 1:00, EMOM x5:00"
→ intervals: [{duration: 60, type: "work"} x5, {duration: 60, type: "rest"}, {duration: 60, type: "work"} x5]

Every 90 seconds:
"Every 90 sec for 9 min: 5 Deadlifts 225#"
→ intervals: [{duration: 90, type: "work"}, {duration: 90, type: "work"}, ... x6]
→ movements: [{name: "Deadlifts", reps: 5, weight: "225#"}]"""
