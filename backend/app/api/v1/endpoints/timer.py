import logging
from fastapi import APIRouter, HTTPException, Query
from app.schemas.workout import WorkoutParseRequest, ParsedWorkout
from app.services.workout_parser import workout_parser
from app.config import settings

logger = logging.getLogger(__name__)
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
    except ValueError as e:
        # Validation errors - can expose to user
        raise HTTPException(
            status_code=400,
            detail=f"Invalid workout format: {str(e)}"
        )
    except Exception as e:
        # Log internal errors but don't expose details
        logger.error(f"Failed to parse workout: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="Failed to parse workout. Please check the format and try again."
        )


@router.get("/health")
async def health_check():
    """
    Health check endpoint
    """
    return {"status": "healthy", "service": "timer"}
