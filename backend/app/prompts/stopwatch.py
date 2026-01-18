"""Stopwatch workout prompt."""

STOPWATCH_PROMPT = """STOPWATCH = Open-ended timer counting UP from 0.

INTERVAL STRUCTURE:
- 1 interval with duration 0 (count-up mode)

EXAMPLES:
"Stopwatch: Practice handstands"
→ intervals: [{duration: 0, label: "Stopwatch", type: "work"}]

"Track time: 100 Burpees"
→ intervals: [{duration: 0, label: "100 Burpees", type: "work"}]"""
