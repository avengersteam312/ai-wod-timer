"""
Agent-based workflow for parsing workouts using OpenAI Agents SDK.

This module implements a two-stage workflow:
1. Classifier agent: Fast classification of workout type
2. Parser agent: Type-specific parsing with appropriate prompts
"""

from pydantic import BaseModel
from typing import Optional
from agents import Agent, ModelSettings, RunContextWrapper, Runner, RunConfig, trace

from app.schemas.workout import WorkoutType
from app.prompts import prompt_manager
from app.prompts.classifier import CLASSIFIER_PROMPT
from app.config import settings
from app.services.workout_type_classifier import workout_type_classifier


# --- Classification Agent Schemas ---


class ClassifySchema(BaseModel):
    """Output schema for the classification agent."""

    category: str


# --- Parser Agent Schemas ---


class MovementSchema(BaseModel):
    """Schema for a single movement in a workout."""

    name: str
    reps: Optional[float] = None
    weight: Optional[str] = None
    distance: Optional[str] = None
    duration: Optional[int] = None
    calories: Optional[int] = None


class IntervalSchema(BaseModel):
    """Schema for a single interval in a workout."""

    type: str  # "work" or "rest"
    duration: float  # in seconds


class ParsedWorkoutSchema(BaseModel):
    """Output schema for the parser agent."""

    workout_type: str
    movements: list[MovementSchema]
    intervals: list[IntervalSchema]
    ai_interpretation: str


# --- Agent Context ---


class ParserAgentContext:
    """Context passed to the parser agent with workout-specific prompts."""

    def __init__(self, workout_prompt: str, base_prompt: str):
        self.workout_prompt = workout_prompt
        self.base_prompt = base_prompt


# --- Agents ---

# Classification agent - fast, cheap model for workout type detection
classify_agent = Agent(
    name="WorkoutClassifier",
    instructions=CLASSIFIER_PROMPT,
    model=settings.AI_CLASSIFIER_MODEL,
    output_type=ClassifySchema,
    model_settings=ModelSettings(temperature=0),
)


def parser_agent_instructions(
    run_context: RunContextWrapper[ParserAgentContext],
    _agent: Agent[ParserAgentContext],
) -> str:
    """Dynamic instructions builder that combines workout-specific and base prompts."""
    ctx = run_context.context
    return f"{ctx.workout_prompt}\n\n{ctx.base_prompt}"


# Parser agent - uses type-specific prompts for accurate parsing
parser_agent = Agent(
    name="WorkoutParser",
    instructions=parser_agent_instructions,
    model=settings.AI_MODEL,
    output_type=ParsedWorkoutSchema,
    model_settings=ModelSettings(temperature=0, max_tokens=2048),
)


# --- Workflow Input ---


class WorkflowInput(BaseModel):
    """Input for the workout parsing workflow."""

    workout_text: str


# --- Workflow Implementation ---


def _get_workout_type_from_category(category: str) -> WorkoutType:
    """Convert category string to WorkoutType enum."""
    category_lower = category.lower()
    try:
        return WorkoutType(category_lower)
    except ValueError:
        return WorkoutType.CUSTOM


async def run_workflow(workflow_input: WorkflowInput) -> dict:
    """
    Main workflow for parsing workouts using AI agents.

    This workflow:
    1. Classifies the workout type using a fast, cheap model
    2. Uses type-specific prompts for accurate parsing
    3. Returns structured workout data

    Args:
        workflow_input: Input containing the workout text

    Returns:
        Dictionary with parsed workout data
    """
    with trace("AI Workout Timer"):
        workout_text = workflow_input.workout_text

        # Step 1: Try local regex classifier first (free, instant)
        local_type = workout_type_classifier.classify(workout_text)

        if local_type != WorkoutType.CUSTOM:
            # Confident match — skip AI classifier
            workout_type = local_type
        else:
            # Ambiguous — fall back to AI classifier
            classify_result = await Runner.run(
                classify_agent,
                input=[
                    {
                        "role": "user",
                        "content": [{"type": "input_text", "text": workout_text}],
                    }
                ],
                run_config=RunConfig(
                    trace_metadata={
                        "__trace_source__": "workout-parser",
                        "step": "classify",
                    }
                ),
            )

            category = classify_result.final_output.category
            workout_type = _get_workout_type_from_category(category)

        # Step 2: Get type-specific prompts
        workout_prompt = prompt_manager.get_workout_prompt(workout_type)
        base_prompt = (
            prompt_manager.get_system_prompt(workout_type)
            .split(workout_prompt)[-1]
            .strip()
            if workout_prompt
            else prompt_manager.get_system_prompt(workout_type)
        )

        # Rebuild the base prompt properly
        from app.prompts.base import BASE_SYSTEM_PROMPT

        base_prompt = BASE_SYSTEM_PROMPT.format(workout_type=workout_type.value)

        # Step 3: Parse workout with type-specific context
        context = ParserAgentContext(
            workout_prompt=workout_prompt, base_prompt=base_prompt
        )

        parser_result = await Runner.run(
            parser_agent,
            input=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "input_text",
                            "text": f"Parse this workout:\n\n{workout_text}",
                        }
                    ],
                }
            ],
            run_config=RunConfig(
                trace_metadata={
                    "__trace_source__": "workout-parser",
                    "step": "parse",
                    "workout_type": workout_type.value,
                }
            ),
            context=context,
        )

        # Step 4: Build result
        parsed = parser_result.final_output

        # Ensure workout type matches our classification
        result = {
            "workout_type": workout_type.value,
            "movements": [m.model_dump(exclude_none=True) for m in parsed.movements],
            "intervals": [i.model_dump() for i in parsed.intervals],
            "ai_interpretation": parsed.ai_interpretation,
        }

        return result


# --- Singleton for easy import ---


class AgentWorkflow:
    """Wrapper class for the agent workflow, matching the pattern of other services."""

    async def parse(self, workout_text: str) -> dict:
        """
        Parse a workout using the agent workflow.

        Args:
            workout_text: Raw workout description

        Returns:
            Dictionary with parsed workout data
        """
        return await run_workflow(WorkflowInput(workout_text=workout_text))


agent_workflow = AgentWorkflow()
