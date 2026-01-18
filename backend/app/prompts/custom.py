"""Custom workout prompt."""

CUSTOM_PROMPT = """CUSTOM = Workouts that don't match standard formats.

Choose the most appropriate structure:
- Single countdown: 1 interval with set duration
- EMOM-style: multiple equal 60s intervals
- Stopwatch: 1 interval with duration 0

EXAMPLES:
"Death by Burpees - add 1 rep each minute"
→ EMOM-style: [{duration: 60, label: "Min 1: 1 rep", type: "work"}, ...]

"Ladder 1-10 Pull-ups"
→ Stopwatch: [{duration: 0, label: "Ladder 1-10", type: "work"}]

Describe structure in ai_interpretation field."""
