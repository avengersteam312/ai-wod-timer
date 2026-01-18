"""EMOM (Every Minute On the Minute) workout prompt."""

EMOM_PROMPT = """EMOM = Every Minute On the Minute. Each minute is a SEPARATE interval.

INTERVAL STRUCTURE:
- "EMOM x3:00" = 3 work intervals of 60s each (NOT 1 interval of 180s)
- E2MOM = each interval is 120s
- E3MOM = each interval is 180s

EXAMPLE:
"EMOM x2:00, rest 1:00, EMOM x3:00"
→ intervals:
  {duration: 60, label: "Min 1", type: "work"}
  {duration: 60, label: "Min 2", type: "work"}
  {duration: 60, label: "Rest", type: "rest"}
  {duration: 60, label: "Min 3", type: "work"}
  {duration: 60, label: "Min 4", type: "work"}
  {duration: 60, label: "Min 5", type: "work"}
= 6 intervals (5 work + 1 rest)"""
