"""Custom workout prompt.

Custom workouts include comprehensive instructions for all workout types,
allowing the parser to handle any workout format.
"""

from app.prompts.amrap import AMRAP_PROMPT
from app.prompts.emom import EMOM_PROMPT
from app.prompts.for_time import FOR_TIME_PROMPT
from app.prompts.tabata import TABATA_PROMPT
from app.prompts.intervals import INTERVALS_PROMPT
from app.prompts.stopwatch import STOPWATCH_PROMPT

CUSTOM_PROMPT = f"""

{AMRAP_PROMPT}

{EMOM_PROMPT}

{FOR_TIME_PROMPT}

{TABATA_PROMPT}

{INTERVALS_PROMPT}

{STOPWATCH_PROMPT}

COMPLEX WORKOUTS (timed blocks with rest between):

"For Max Distance: At minute 0:00 Every 3:00 x 4 sets 100m dual KB farmers carry max distance row, At minute 15:00 Every 3:00 x 4 sets 10 shuttle runs max distance assault bike"
→ intervals: [
    {{duration: 180, type: "work"}},
    {{duration: 180, type: "work"}},
    {{duration: 180, type: "work"}},
    {{duration: 180, type: "work"}},
    {{duration: 180, type: "rest"}},
    {{duration: 180, type: "work"}},
    {{duration: 180, type: "work"}},
    {{duration: 180, type: "work"}},
    {{duration: 180, type: "work"}}
]
→ movements: [{{name: "Dual KB Farmers Carry", distance: "100m"}}, {{name: "Row"}}, {{name: "Shuttle Runs", reps: 10}}, {{name: "Assault Bike"}}]

"For Quality: 8:00 bike every 2:00 perform 30 single unders, 8:00 row every 2:00 perform 30 double unders, 8:00 bike every 2:00 perform 30 single unders, 8:00 row every 2:00 perform 30 double unders"
→ intervals: [
    {{duration: 120, type: "work"}},
    {{duration: 120, type: "work"}},
    {{duration: 120, type: "work"}},
    {{duration: 120, type: "work"}},
    {{duration: 120, type: "work"}},
    {{duration: 120, type: "work"}},
    {{duration: 120, type: "work"}},
    {{duration: 120, type: "work"}},
    {{duration: 120, type: "work"}},
    {{duration: 120, type: "work"}},
    {{duration: 120, type: "work"}},
    {{duration: 120, type: "work"}},
    {{duration: 120, type: "work"}},
    {{duration: 120, type: "work"}},
    {{duration: 120, type: "work"}},
    {{duration: 120, type: "work"}}
]
→ movements: [{{name: "Bike"}}, {{name: "Single Unders", reps: 30}}, {{name: "Row"}}, {{name: "Double Unders", reps: 30}}]
"""
