import time
import structlog
from fastapi import APIRouter, HTTPException, Query, UploadFile, File
from app.schemas.workout import WorkoutParseRequest, ParsedWorkout
from app.services.workout_parser import workout_parser
from app.services.ai_service import ai_service
from app.config import settings
from app.observability.metrics import (
    ai_parse_errors_total,
    ai_parse_requests_total,
    workouts_parsed_total,
    ai_parse_duration,
)

log = structlog.get_logger(__name__)
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
    start = time.perf_counter()
    try:
        parser = _get_parser(use_agent)
        parsed = await parser.parse(request.workout_text)
        duration = time.perf_counter() - start
        workout_type = parsed.workout_type.value
        ai_parse_requests_total.add(1, {"workout_type": workout_type, "model": "standard"})
        workouts_parsed_total.add(1, {"workout_type": workout_type})
        ai_parse_duration.record(duration, {"workout_type": workout_type, "stage": "parse"})
        return parsed
    except ValueError as e:
        ai_parse_errors_total.add(1, {"workout_type": "unknown", "error_type": "validation"})
        raise HTTPException(
            status_code=400,
            detail=f"Invalid workout format: {str(e)}"
        )
    except Exception as e:
        ai_parse_errors_total.add(1, {"workout_type": "unknown", "error_type": "internal"})
        log.error("parse.failed", exc_info=True, error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to parse workout. Please check the format and try again."
        )


@router.post("/parse-image", response_model=ParsedWorkout)
async def parse_workout_from_image(
    file: UploadFile = File(..., description="Image file containing workout text"),
    use_agent: bool = Query(
        default=None,
        description="Override to use agent-based parser (True) or standard parser (False)"
    )
):
    """
    Parse workout from an image using a two-step process:
    1. GPT-4o-mini Vision extracts text from image (token-efficient)
    2. Existing text parser converts to timer config (reuses optimized logic)

    This endpoint accepts an image (JPEG, PNG, WebP, GIF) containing workout text
    (e.g., whiteboard photo, printed workout, handwritten notes) and returns
    a structured workout with timer configuration.

    Supports the same workout types as the text parser:
    - AMRAP, EMOM, For Time, Tabata, Rounds with rest, Custom intervals
    """
    # Validate file type
    allowed_types = ["image/jpeg", "image/png", "image/webp", "image/gif"]
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed types: {', '.join(allowed_types)}"
        )

    # Limit file size (5MB - reduced since we compress client-side)
    max_size = 5 * 1024 * 1024
    content = await file.read()
    if len(content) > max_size:
        raise HTTPException(
            status_code=400,
            detail="File too large. Maximum size is 5MB."
        )

    try:
        # Step 1: Extract text from image using Vision API (cheap, fast)
        extracted_text, workout_name = await ai_service.extract_text_from_image(
            content, file.content_type
        )

        if not extracted_text.strip():
            raise ValueError("No workout text found in image")

        # Step 2: Parse extracted text using existing parser (reuses all logic)
        parser = _get_parser(use_agent)
        result = await parser.parse(extracted_text)

        # Override raw_text with extracted text so it shows in notes
        result.raw_text = extracted_text

        # Add workout name as interpretation if available
        if workout_name and workout_name != "Workout":
            result.ai_interpretation = workout_name

        return result

    except ValueError as e:
        raise HTTPException(
            status_code=400,
            detail=str(e)
        )
    except Exception as e:
        ai_parse_errors_total.add(1, {"workout_type": "unknown", "error_type": "image_parse"})
        log.error("parse_image.failed", exc_info=True, error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to parse workout from image. Please try again with a clearer image."
        )


@router.get("/health")
async def health_check():
    """
    Health check endpoint
    """
    return {"status": "healthy", "service": "timer"}
