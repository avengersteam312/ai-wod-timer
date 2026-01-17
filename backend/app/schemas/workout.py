from pydantic import BaseModel, Field
from typing import Optional, List
from enum import Enum


class WorkoutType(str, Enum):
    AMRAP = "amrap"
    EMOM = "emom"
    FOR_TIME = "for_time"
    TABATA = "tabata"
    CHIPPER = "chipper"
    ROUNDS = "rounds"
    CUSTOM = "custom"


class Movement(BaseModel):
    name: str
    reps: Optional[int] = None
    duration: Optional[int] = None  # seconds
    weight: Optional[str] = None
    notes: Optional[str] = None


class AudioCue(BaseModel):
    time: int  # seconds from start (or from end if negative)
    message: str
    type: str = "announcement"  # announcement, warning, completion


class Interval(BaseModel):
    duration: int  # seconds
    label: str
    type: str = "work"  # work, rest, transition


class TimerConfig(BaseModel):
    type: str  # countdown, intervals, rounds, tabata
    total_seconds: Optional[int] = None
    rounds: Optional[int] = None
    intervals: List[Interval] = Field(default_factory=list)
    audio_cues: List[AudioCue] = Field(default_factory=list)
    rest_between_rounds: Optional[int] = None


class ParsedWorkout(BaseModel):
    workout_type: WorkoutType
    movements: List[Movement]
    rounds: Optional[int] = None
    duration: Optional[int] = None  # total workout duration in seconds
    time_cap: Optional[int] = None
    rest_between_rounds: Optional[int] = None
    timer_config: TimerConfig
    raw_text: str
    ai_interpretation: Optional[str] = None


class WorkoutParseRequest(BaseModel):
    workout_text: str = Field(..., min_length=1, description="Raw workout description")

    class Config:
        json_schema_extra = {
            "example": {
                "workout_text": "AMRAP 20min:\n10 Wall Balls (20/14 lbs)\n10 Box Jumps (24/20 in)\n10 Burpees"
            }
        }
