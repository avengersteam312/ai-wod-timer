"""Tabata workout prompt."""

TABATA_PROMPT = """TABATA = 20 seconds work / 10 seconds rest protocol.

CONCEPT:
- Fixed timing: 20 seconds work, 10 seconds rest
- Standard format: 8 rounds per exercise (4 minutes total)
- High intensity interval training protocol
- Named after Dr. Izumi Tabata's research

RULES:
- Alternating work (20s) and rest (10s) intervals
- 8 rounds = 16 interval objects per exercise
- type: "work" for 20s intervals, "rest" for 10s intervals
- MULTI-EXERCISE TABATA:
- Each exercise gets full 8 rounds (16 intervals)
- Add 60 seconds rest between different exercises
- Total intervals = (exercises × 16) + (exercises - 1) rest intervals

EXAMPLES:

Single exercise:
"Tabata: Air Squats"
→ intervals: [{duration: 20, type: "work"}, {duration: 10, type: "rest"}] x8 = 16 intervals
→ movements: [{name: "Air Squats"}]

With rep target:
"Tabata Push-ups (max reps)"
→ intervals: [{duration: 20, type: "work"}, {duration: 10, type: "rest"}] x8 = 16 intervals
→ movements: [{name: "Push-ups"}]

Two exercises:
"Tabata: Burpees, then Mountain Climbers"
→ intervals: [{duration: 20, type: "work"}, {duration: 10, type: "rest"}] x8, {duration: 60, type: "rest"}, [{duration: 20, type: "work"}, {duration: 10, type: "rest"}] x8 = 33 intervals
→ movements: [{name: "Burpees"}, {name: "Mountain Climbers"}]

Four exercises:
"Tabata: Squats, Push-ups, Sit-ups, Lunges"
→ intervals: 4 exercises × 16 intervals + 3 rest periods = 67 intervals
→ movements: [{name: "Squats"}, {name: "Push-ups"}, {name: "Sit-ups"}, {name: "Lunges"}]

Weighted tabata:
"Tabata KB Swings 35#"
→ intervals: [{duration: 20, type: "work"}, {duration: 10, type: "rest"}] x8 = 16 intervals
→ movements: [{name: "KB Swings", weight: "35#"}]

Tabata style notation:
"20/10 x 8: Jump Squats"
→ intervals: [{duration: 20, type: "work"}, {duration: 10, type: "rest"}] x8 = 16 intervals
→ movements: [{name: "Jump Squats"}]"""
