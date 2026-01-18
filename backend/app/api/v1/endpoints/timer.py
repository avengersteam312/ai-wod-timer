from fastapi import APIRouter, HTTPException
from app.schemas.workout import WorkoutParseRequest, ParsedWorkout
from app.services.workout_parser import workout_parser
import traceback

router = APIRouter()


@router.post("/parse", response_model=ParsedWorkout)
async def parse_workout(request: WorkoutParseRequest):
    """
    Parse workout text and generate AI-powered timer configuration

    This endpoint takes raw workout text (e.g., from a whiteboard or programming site)
    and returns a structured workout with timer configuration.

    Supports:
    - AMRAP (As Many Rounds As Possible)
    - EMOM (Every Minute On the Minute)
    - For Time
    - Tabata
    - Rounds with rest
    - Custom intervals
    """
    try:
        parsed = await workout_parser.parse(request.workout_text)
        return parsed
    except Exception as e:
        print(f"Parse endpoint error: {str(e)}")
        print(f"Full traceback: {traceback.format_exc()}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to parse workout: {str(e)}"
        )


@router.get("/health")
async def health_check():
    """
    Health check endpoint
    """
    return {"status": "healthy", "service": "timer"}
