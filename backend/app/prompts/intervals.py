"""Intervals workout prompt."""

INTERVALS_PROMPT = """INTERVALS = Custom work/rest timing (NOT Tabata 20/10).

INTERVAL STRUCTURE:
- Alternating work and rest intervals
- "30/15 x 4" = 8 intervals (4 work of 30s + 4 rest of 15s)

EXAMPLES:
"30/15 x 4 rounds"
→ intervals:
  {duration: 30, label: "Work", type: "work"}
  {duration: 15, label: "Rest", type: "rest"}
  ... (repeat 4x)

"40 on 20 off x 6: Burpees"
→ 12 intervals alternating 40s work / 20s rest

Circuit: "30/15: Squats, Push-ups, Lunges x 3"
→ Cycle through exercises with work/rest for each"""
