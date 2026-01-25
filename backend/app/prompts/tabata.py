"""Tabata workout prompt."""

TABATA_PROMPT = """TABATA = 20 seconds work / 10 seconds rest protocol.

CONCEPT:
- Fixed timing: 20 seconds work, 10 seconds rest
- Standard format: 8 rounds per exercise (4 minutes total = 16 interval objects)
- High intensity interval training protocol

RULES:
- Alternating work (20s) and rest (10s) intervals
- 8 rounds = 16 interval objects per exercise (work, rest, work, rest, ...)
- type: "work" for 20s intervals, "rest" for 10s intervals
- NEVER multiply durations - create separate interval objects

EXAMPLES:

Single exercise (8 rounds = 16 intervals):
"Tabata: Air Squats"
→ intervals: [
    {duration: 20, type: "work"}, {duration: 10, type: "rest"},
    {duration: 20, type: "work"}, {duration: 10, type: "rest"},
    {duration: 20, type: "work"}, {duration: 10, type: "rest"},
    {duration: 20, type: "work"}, {duration: 10, type: "rest"},
    {duration: 20, type: "work"}, {duration: 10, type: "rest"},
    {duration: 20, type: "work"}, {duration: 10, type: "rest"},
    {duration: 20, type: "work"}, {duration: 10, type: "rest"},
    {duration: 20, type: "work"}, {duration: 10, type: "rest"}
]
→ movements: [{name: "Air Squats"}]

Weighted tabata (8 rounds = 16 intervals):
"Tabata KB Swings 35#"
→ intervals: [
    {duration: 20, type: "work"}, {duration: 10, type: "rest"},
    {duration: 20, type: "work"}, {duration: 10, type: "rest"},
    {duration: 20, type: "work"}, {duration: 10, type: "rest"},
    {duration: 20, type: "work"}, {duration: 10, type: "rest"},
    {duration: 20, type: "work"}, {duration: 10, type: "rest"},
    {duration: 20, type: "work"}, {duration: 10, type: "rest"},
    {duration: 20, type: "work"}, {duration: 10, type: "rest"},
    {duration: 20, type: "work"}, {duration: 10, type: "rest"}
]
→ movements: [{name: "KB Swings", weight: "35#"}]"""
