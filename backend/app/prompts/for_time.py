"""For Time workout prompt."""

FOR_TIME_PROMPT = """FOR TIME = Complete all work as fast as possible.

INTERVAL STRUCTURE:
- With time cap: 1 interval of time cap duration
- Without time cap: 1 interval with duration 0 (stopwatch)

EXAMPLES:
"For Time (15 min cap): 50 Wall Balls"
→ intervals: [{duration: 900, label: "For Time", type: "work"}]

"For Time: 100 Burpees" (no cap)
→ intervals: [{duration: 0, label: "For Time", type: "work"}]

NOTES:
- "21-15-9": Rep scheme (not separate intervals)
- "5 RFT": 5 rounds for time (still 1 interval)"""
