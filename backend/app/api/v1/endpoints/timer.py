from fastapi import APIRouter, HTTPException, Query
from app.schemas.workout import WorkoutParseRequest, ParsedWorkout
from app.services.workout_parser import workout_parser
from app.config import settings
import traceback

router = APIRouter()


def _get_parser(use_agent: bool = None):
    """Get the appropriate parser based on config or override."""
    # Use explicit parameter if provided, otherwise use config
    should_use_agent = use_agent if use_agent is not None else settings.USE_AGENT_WORKFLOW

    if should_use_agent:
        from app.services.agent_workout_parser import agent_workout_parser
        return agent_workout_parser
    return workout_parser


@router.post("/parse", response_model=ParsedWorkout)
async def parse_workout(
    request: WorkoutParseRequest,
    use_agent: bool = Query(
        default=None,
        description="Override to use agent-based parser (True) or standard parser (False)"
    )
):
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

    Query Parameters:
    - use_agent: Optional override to use agent-based parser (default: from config)
    """
    try:
        parser = _get_parser(use_agent)
        parsed = await parser.parse(request.workout_text)
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
