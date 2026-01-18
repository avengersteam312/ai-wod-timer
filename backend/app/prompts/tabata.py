"""Tabata workout prompt."""

TABATA_PROMPT = """TABATA = 20s work / 10s rest, 8 rounds (16 intervals total).

INTERVAL STRUCTURE:
- Alternating work (20s) and rest (10s)
- 8 rounds = 16 interval objects

EXAMPLE:
"Tabata: Air Squats"
→ intervals (8 rounds = 16 intervals):
  {duration: 20, label: "Air Squats", type: "work"}
  {duration: 10, label: "Rest", type: "rest"}
  ... (repeat 8x)

Multi-exercise: each exercise gets 8 rounds, add 60s rest between exercises."""
