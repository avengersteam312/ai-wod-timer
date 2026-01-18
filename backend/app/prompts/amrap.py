"""AMRAP (As Many Rounds As Possible) workout prompt."""

AMRAP_PROMPT = """AMRAP = As Many Rounds As Possible within a time limit.

INTERVAL STRUCTURE:
- 1 single interval for entire duration
- "AMRAP 20" = 1 interval of 1200s

EXAMPLE:
"AMRAP 12: 10 KB Swings, 15 Box Jumps"
→ intervals: [{duration: 720, label: "AMRAP 12 min", type: "work"}]"""
